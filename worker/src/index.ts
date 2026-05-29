// Introibo feedback worker.
//
// POST /feedback        — accept feedback submissions, insert into D1
// GET  /healthz         — liveness probe
//
// CORS is permissive — the Flutter client doesn't send an Origin header from
// the device, but we keep the wildcard for browser-side debugging.

interface Env {
  DB: D1Database;
}

const MAX_BODY_BYTES = 8 * 1024; // 8 KB
const RATE_LIMIT_PER_HOUR = 5;

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
    return json({ ok: false, error: 'not found' }, { status: 404 });
  },
};
