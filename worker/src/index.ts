// ParishFinder feedback worker.
//
// POST /feedback        — accept feedback submissions, insert into D1
// GET  /healthz         — liveness probe
// GET  /admin           — Basic-Auth-protected HTML dashboard (browse feedback)
// GET  /admin/data      — Basic-Auth-protected JSON feed the dashboard fetches
// POST /admin/digest    — Basic-Auth-protected manual digest trigger (testing)
//
// scheduled()           — daily Cron Trigger: posts a 24h digest to Discord.
//
// CORS is permissive on /feedback — the Flutter client doesn't send an Origin
// header from the device, but we keep the wildcard for browser-side debugging.
// Admin routes are deliberately NOT CORS-open and require Basic Auth.

interface Env {
  DB: D1Database;
  // Set via `wrangler secret put …`. Both optional so the worker still boots
  // (and /feedback keeps working) before they're configured.
  DISCORD_WEBHOOK_URL?: string; // digest destination
  ADMIN_PASSWORD?: string; // Basic-Auth password for /admin*
  DASHBOARD_URL?: string; // optional link included in the digest
}

const MAX_BODY_BYTES = 8 * 1024; // 8 KB
const RATE_LIMIT_PER_HOUR = 5;
const DISCORD_MAX = 2000; // hard Discord content limit; we stay under it

const CORS_HEADERS: HeadersInit = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Access-Control-Max-Age': '86400',
};

function json(data: unknown, init: ResponseInit = {}): Response {
  return new Response(JSON.stringify(data), {
    ...init,
    headers: {
      ...CORS_HEADERS,
      'Content-Type': 'application/json',
      ...(init.headers ?? {}),
    },
  });
}

interface FeedbackBody {
  kind?: string;
  body?: string;
  parish_name?: string;
  parish_id?: string;
  status?: string;
  issue_categories?: string[] | string;
  reply_email?: string;
  app_version?: string;
  build_number?: string;
  platform?: string;
}

function asString(v: unknown, max = 200): string | null {
  if (typeof v !== 'string') return null;
  const trimmed = v.trim();
  if (!trimmed) return null;
  return trimmed.slice(0, max);
}

async function isRateLimited(env: Env, ip: string): Promise<boolean> {
  const row = await env.DB
    .prepare(
      "SELECT COUNT(*) AS n FROM feedback_rate WHERE client_ip = ? AND created_at > datetime('now', '-1 hour')",
    )
    .bind(ip)
    .first<{ n: number }>();
  return (row?.n ?? 0) >= RATE_LIMIT_PER_HOUR;
}

async function recordRate(env: Env, ip: string): Promise<void> {
  await env.DB.prepare('INSERT INTO feedback_rate (client_ip) VALUES (?)').bind(ip).run();
}

// The ledger is only ever read over a one-hour window, so anything older is
// dead weight. Pruned from the daily cron rather than inline, to keep the
// submission path at one read + two writes. A day's grace, not an hour, so a
// missed cron can't cause a row to be dropped while it still counts.
async function pruneRateLedger(env: Env): Promise<void> {
  try {
    await env.DB.prepare(
      "DELETE FROM feedback_rate WHERE created_at < datetime('now', '-1 day')",
    ).run();
  } catch (err) {
    // Never let housekeeping take down the digest.
    console.error('feedback_rate prune failed', err);
  }
}

async function handleFeedback(req: Request, env: Env): Promise<Response> {
  const contentLength = Number(req.headers.get('content-length') ?? 0);
  if (contentLength > MAX_BODY_BYTES) {
    return json({ ok: false, error: 'payload too large' }, { status: 413 });
  }

  let payload: FeedbackBody;
  try {
    payload = (await req.json()) as FeedbackBody;
  } catch {
    return json({ ok: false, error: 'invalid json' }, { status: 400 });
  }

  const kind = asString(payload.kind, 32);
  const body = asString(payload.body, 4000);
  if (!kind || !body) {
    return json({ ok: false, error: 'kind and body are required' }, { status: 400 });
  }
  if (kind !== 'general' && kind !== 'parish_data') {
    return json({ ok: false, error: 'unknown kind' }, { status: 400 });
  }

  const ip = req.headers.get('CF-Connecting-IP') ?? 'unknown';
  if (await isRateLimited(env, ip)) {
    return json(
      { ok: false, error: 'rate limit exceeded — try again later' },
      { status: 429 },
    );
  }

  const issueCategories = Array.isArray(payload.issue_categories)
    ? payload.issue_categories.join(',').slice(0, 200)
    : asString(payload.issue_categories, 200);

  const result = await env.DB
    .prepare(
      `INSERT INTO feedback
        (kind, parish_name, parish_id, status, issue_categories,
         reply_email, body, app_version, build_number, platform, client_ip)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    )
    .bind(
      kind,
      asString(payload.parish_name, 200),
      asString(payload.parish_id, 64),
      asString(payload.status, 32),
      issueCategories,
      asString(payload.reply_email, 200),
      body,
      asString(payload.app_version, 32),
      asString(payload.build_number, 32),
      asString(payload.platform, 32),
      ip,
    )
    .run();

  await recordRate(env, ip);

  return json({ ok: true, id: result.meta.last_row_id });
}

// ───────────────────────── admin auth ─────────────────────────

// Constant-time string compare so a wrong password can't be teased apart
// character-by-character via response timing.
function timingSafeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const ab = enc.encode(a);
  const bb = enc.encode(b);
  if (ab.length !== bb.length) return false;
  let diff = 0;
  for (let i = 0; i < ab.length; i++) diff |= ab[i] ^ bb[i];
  return diff === 0;
}

// Basic Auth: any username, password must match ADMIN_PASSWORD. If the secret
// isn't configured we fail closed (deny) rather than open.
function checkAuth(req: Request, env: Env): boolean {
  if (!env.ADMIN_PASSWORD) return false;
  const header = req.headers.get('Authorization') ?? '';
  if (!header.startsWith('Basic ')) return false;
  let decoded = '';
  try {
    decoded = atob(header.slice(6).trim());
  } catch {
    return false;
  }
  const idx = decoded.indexOf(':');
  const pass = idx >= 0 ? decoded.slice(idx + 1) : decoded;
  return timingSafeEqual(pass, env.ADMIN_PASSWORD);
}

function unauthorized(): Response {
  return new Response('Authentication required.', {
    status: 401,
    headers: {
      'WWW-Authenticate': 'Basic realm="ParishFinder Admin", charset="UTF-8"',
      'Cache-Control': 'no-store',
    },
  });
}

async function handleAdminData(req: Request, env: Env): Promise<Response> {
  const url = new URL(req.url);
  const limit = Math.min(Math.max(Number(url.searchParams.get('limit') ?? 200), 1), 1000);
  const kind = url.searchParams.get('kind');

  let sql = `SELECT id, created_at, kind, parish_name, parish_id, status,
                    issue_categories, reply_email, body, app_version,
                    build_number, platform, client_ip
             FROM feedback`;
  const binds: unknown[] = [];
  if (kind === 'general' || kind === 'parish_data') {
    sql += ' WHERE kind = ?';
    binds.push(kind);
  }
  sql += ' ORDER BY id DESC LIMIT ?';
  binds.push(limit);

  const { results } = await env.DB.prepare(sql).bind(...binds).all();
  return new Response(JSON.stringify({ ok: true, rows: results ?? [] }), {
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  });
}

// ───────────────────────── digest ─────────────────────────

interface DigestRow {
  id: number;
  created_at: string;
  kind: string;
  parish_name: string | null;
  status: string | null;
  issue_categories: string | null;
  reply_email: string | null;
  body: string | null;
}

function formatDigest(rows: DigestRow[], env: Env): string {
  const date = new Date().toISOString().slice(0, 10);
  if (rows.length === 0) {
    // Heartbeat: a quiet day still pings so the pipeline is visibly alive.
    return `🕊️ **ParishFinder feedback** — ${date}\nNo new feedback in the last 24h.`;
  }

  const gen = rows.filter((r) => r.kind === 'general').length;
  const pd = rows.length - gen;
  let out =
    `📥 **ParishFinder feedback** — ${date}\n` +
    `${rows.length} new (${gen} general · ${pd} parish data)\n`;

  const dashLink = env.DASHBOARD_URL ? `\n\n🔗 <${env.DASHBOARD_URL}>` : '';
  const budget = DISCORD_MAX - dashLink.length - 40; // headroom for "…and N more"

  let shown = 0;
  for (const r of rows) {
    const tag =
      r.kind === 'parish_data'
        ? `🏛️ ${r.parish_name ?? 'parish'}${r.status ? ` [${r.status}]` : ''}`
        : '💬 general';
    const email = r.reply_email ? ` — ✉️ ${r.reply_email}` : '';
    const body = (r.body ?? '').replace(/\s+/g, ' ').trim();
    const bodyShort = body.length > 160 ? `${body.slice(0, 159)}…` : body;
    const line = `\n• **#${r.id}** ${tag}${email}\n  ${bodyShort}`;
    if (out.length + line.length > budget) {
      out += `\n…and ${rows.length - shown} more.`;
      break;
    }
    out += line;
    shown++;
  }
  return out + dashLink;
}

async function postDiscord(url: string, content: string): Promise<void> {
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    // allowed_mentions: parse [] neutralizes any @everyone/@here that could
    // ride in on user-submitted feedback text.
    body: JSON.stringify({ content, allowed_mentions: { parse: [] } }),
  });
  if (!res.ok) {
    console.error('Discord webhook failed:', res.status, await res.text());
  }
}

async function sendDigest(env: Env): Promise<void> {
  if (!env.DISCORD_WEBHOOK_URL) {
    console.log('DISCORD_WEBHOOK_URL not configured; skipping digest.');
    return;
  }
  const { results } = await env.DB
    .prepare(
      `SELECT id, created_at, kind, parish_name, status, issue_categories,
              reply_email, body
       FROM feedback
       WHERE created_at > datetime('now', '-1 day')
       ORDER BY id DESC`,
    )
    .all<DigestRow>();
  await postDiscord(env.DISCORD_WEBHOOK_URL, formatDigest(results ?? [], env));
}

// ───────────────────────── entrypoints ─────────────────────────

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    if (req.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    const url = new URL(req.url);

    if (url.pathname === '/healthz') {
      return json({ ok: true });
    }
    if (url.pathname === '/feedback' && req.method === 'POST') {
      return handleFeedback(req, env);
    }

    // Admin surface — all Basic-Auth gated.
    if (url.pathname === '/admin' && req.method === 'GET') {
      if (!checkAuth(req, env)) return unauthorized();
      return new Response(ADMIN_HTML, {
        headers: { 'Content-Type': 'text/html; charset=UTF-8', 'Cache-Control': 'no-store' },
      });
    }
    if (url.pathname === '/admin/data' && req.method === 'GET') {
      if (!checkAuth(req, env)) return unauthorized();
      return handleAdminData(req, env);
    }
    if (url.pathname === '/admin/digest' && req.method === 'POST') {
      if (!checkAuth(req, env)) return unauthorized();
      await sendDigest(env);
      return json({ ok: true, sent: true });
    }

    return json({ ok: false, error: 'not found' }, { status: 404 });
  },

  // Daily Cron Trigger (see wrangler.toml [triggers]). Posts a 24h digest.
  async scheduled(_event: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    ctx.waitUntil(sendDigest(env));
    ctx.waitUntil(pruneRateLedger(env));
  },
};

// ───────────────────────── dashboard page ─────────────────────────
// Self-contained: inline CSS + JS, no external requests. Fetches /admin/data
// (same origin, so the browser reuses the Basic-Auth credentials).
const ADMIN_HTML = /* html */ `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ParishFinder — Feedback</title>
<style>
  :root {
    --bg:#faf6ee; --card:#fffcf4; --ink:#1c1512; --muted:#6b5d54;
    --line:#e6ddcf; --accent:#8c1f1f; --gold:#8c5a14;
    --pill-gen:#e8eef6; --pill-gen-ink:#33506e;
    --pill-pd:#f3e7e7; --pill-pd-ink:#8c1f1f;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg:#000; --card:#14100f; --ink:#f3ece2; --muted:#a9998c;
      --line:#2a221e; --accent:#d4a24a; --gold:#d4a24a;
      --pill-gen:#1b2635; --pill-gen-ink:#9dc0ec;
      --pill-pd:#2c1616; --pill-pd-ink:#e59a9a;
    }
  }
  * { box-sizing:border-box; }
  body { margin:0; background:var(--bg); color:var(--ink);
    font:15px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; }
  header { position:sticky; top:0; background:var(--bg); border-bottom:1px solid var(--line);
    padding:14px 18px; display:flex; gap:14px; align-items:center; flex-wrap:wrap; }
  h1 { font:600 18px/1 Georgia,"Cormorant Garamond",serif; margin:0; color:var(--accent); }
  .stats { color:var(--muted); font-size:13px; }
  .grow { flex:1; }
  select, input, button { font:inherit; padding:7px 10px; border:1px solid var(--line);
    border-radius:8px; background:var(--card); color:var(--ink); }
  button { cursor:pointer; }
  button:hover { border-color:var(--accent); }
  main { padding:14px 18px 60px; max-width:980px; margin:0 auto; }
  .row { background:var(--card); border:1px solid var(--line); border-radius:12px;
    padding:12px 14px; margin-bottom:10px; }
  .row summary { list-style:none; cursor:pointer; display:flex; gap:10px; align-items:baseline; flex-wrap:wrap; }
  .row summary::-webkit-details-marker { display:none; }
  .id { color:var(--muted); font-variant-numeric:tabular-nums; font-size:13px; }
  .pill { font-size:11px; font-weight:700; letter-spacing:.4px; padding:2px 8px; border-radius:20px; }
  .pill.general { background:var(--pill-gen); color:var(--pill-gen-ink); }
  .pill.parish_data { background:var(--pill-pd); color:var(--pill-pd-ink); }
  .status { font-size:11px; color:var(--muted); }
  .when { color:var(--muted); font-size:12px; }
  .parish { font-weight:600; }
  .snippet { color:var(--ink); width:100%; margin-top:4px; opacity:.92; }
  .detail { margin-top:10px; border-top:1px dashed var(--line); padding-top:10px;
    display:grid; grid-template-columns:120px 1fr; gap:4px 12px; font-size:13px; }
  .detail dt { color:var(--muted); }
  .detail dd { margin:0; word-break:break-word; white-space:pre-wrap; }
  .empty, .err { color:var(--muted); text-align:center; padding:40px; }
  .err { color:var(--accent); }
  a { color:var(--gold); }
</style>
</head>
<body>
<header>
  <h1>ParishFinder Feedback</h1>
  <span class="stats" id="stats">Loading…</span>
  <span class="grow"></span>
  <input id="q" type="search" placeholder="Filter text…" style="width:150px">
  <select id="kind">
    <option value="">All kinds</option>
    <option value="general">General</option>
    <option value="parish_data">Parish data</option>
  </select>
  <button id="refresh">Refresh</button>
</header>
<main id="list"><p class="empty">Loading…</p></main>
<script>
  const listEl = document.getElementById('list');
  const statsEl = document.getElementById('stats');
  const kindEl = document.getElementById('kind');
  const qEl = document.getElementById('q');
  let rows = [];

  const esc = (s) => (s == null ? '' : String(s)).replace(/[&<>"]/g,
    c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));

  const DETAIL_FIELDS = ['created_at','kind','parish_name','parish_id','status',
    'issue_categories','reply_email','app_version','build_number','platform','client_ip','body'];

  function render() {
    const q = qEl.value.trim().toLowerCase();
    const shown = rows.filter(r => !q ||
      [r.body, r.parish_name, r.reply_email].some(v => (v||'').toLowerCase().includes(q)));
    statsEl.textContent = shown.length + ' of ' + rows.length + ' shown';
    if (!shown.length) { listEl.innerHTML = '<p class="empty">No matching feedback.</p>'; return; }
    listEl.innerHTML = shown.map(r => {
      const title = r.kind === 'parish_data'
        ? '<span class="parish">' + esc(r.parish_name || 'Parish') + '</span>'
          + (r.status ? ' <span class="status">[' + esc(r.status) + ']</span>' : '')
        : '<span class="parish">General feedback</span>';
      const detail = DETAIL_FIELDS.map(f =>
        '<dt>' + f + '</dt><dd>' + (esc(r[f]) || '<span style=opacity:.5>—</span>') + '</dd>').join('');
      return '<details class="row"><summary>'
        + '<span class="id">#' + r.id + '</span>'
        + '<span class="pill ' + esc(r.kind) + '">' + (r.kind === 'parish_data' ? 'PARISH' : 'GENERAL') + '</span>'
        + title
        + '<span class="when">' + esc(r.created_at) + ' UTC</span>'
        + '<span class="snippet">' + esc(r.body || '') + '</span>'
        + '</summary><dl class="detail">' + detail + '</dl></details>';
    }).join('');
  }

  async function load() {
    listEl.innerHTML = '<p class="empty">Loading…</p>';
    try {
      const res = await fetch('/admin/data?limit=500' + (kindEl.value ? '&kind=' + kindEl.value : ''),
        { headers: { 'Accept': 'application/json' } });
      if (!res.ok) throw new Error('HTTP ' + res.status);
      const data = await res.json();
      rows = data.rows || [];
      render();
    } catch (e) {
      listEl.innerHTML = '<p class="err">Failed to load: ' + esc(e.message) + '</p>';
      statsEl.textContent = 'error';
    }
  }

  document.getElementById('refresh').onclick = load;
  kindEl.onchange = load;
  qEl.oninput = render;
  load();
</script>
</body>
</html>`;
