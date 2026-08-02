# Security hardening — status

Scoped 2026-08-01, worked 2026-08-02. Items 3 and 4 are **done**; items 1, 2,
and 5 are dashboard work that can't be done from the CLI (wrangler's OAuth token
carries `zone (read)` but no WAF or `dns_records (write)` scopes).

## The short version

The **static site needs no firewall rules.** It's HTML, CSS, and self-hosted
fonts — no forms, no auth, no server code, nothing to inject into. Cloudflare
absorbs volumetric attacks for free and Pages bandwidth is unmetered, so there's
no cost-abuse angle either. WAF custom rules there would be theater.

The **Worker is the real attack surface.** WAF and rate-limiting rules are
*zone-scoped*, so nothing could be applied while it lived only on
`introibo-feedback.mfgarvin.workers.dev` (Cloudflare's zone, not ours). That
blocker is now gone — see item 3.

---

## 1. Protect `/admin*` — highest priority · TODO (dashboard)

**The gap:** Basic Auth is the only thing guarding the dashboard, and unlike
`/feedback` (5/hour/IP, enforced in D1) the admin routes have **no throttle at
all**. The password can be ground down unmetered. What's behind it is submitter
email addresses — PII under our own privacy policy.

The auth code itself is fine (`worker/src/index.ts:157` — fails closed when
`ADMIN_PASSWORD` is unset, timing-safe compare, admin routes correctly excluded
from the permissive CORS). The problem is the absence of a brute-force limit,
not the check.

**Decided fix: Cloudflare Access.** Free for up to 50 users, removes the shared
password as an attack surface entirely, needs no code change. The prerequisite
(item 3) is now in place, so this is ready to do:

1. Zero Trust → Access → Applications → **Add an application** → *Self-hosted*
2. Application name: `ParishFinder admin`; session duration: whatever suits.
3. Public hostname: subdomain `api`, domain `parishfinder.app`, path `admin`
   (Access matches the path prefix, so this covers `/admin`, `/admin/data`, and
   `/admin/digest`).
4. Policy: name `Owner`, action **Allow**, include → **Emails** →
   `mfjgarvin@gmail.com`.
5. Identity: the one-time PIN provider is on by default and is enough — no need
   to wire up Google/GitHub login.
6. Save, then load `https://api.parishfinder.app/admin` in a fresh browser
   profile and confirm you get the Access login screen, not the Basic Auth
   prompt.

**Keep the Basic Auth check in the Worker** as defence in depth; don't remove
it. Note the consequence for automation: `POST /admin/digest` via `curl -u`
(documented in `worker/README.md`) will start failing at the Access layer once
this is on. Either use an Access **service token** for that call, or just wait
for the daily cron — the `scheduled()` handler runs inside the Worker and never
passes through Access, so the digest itself is unaffected.

## 2. Edge rate-limit on `/feedback` · TODO (dashboard)

The D1 limit is correct but *late*: every request writes a row to
`feedback_rate` **before** being counted (`worker/src/index.ts:103`–`136`), so an
IP-rotating flood turns into D1 write amplification we pay for. An edge rule
sheds it before the Worker ever runs.

Security → WAF → Rate limiting rules, on the `parishfinder.app` zone:

- Match: `http.host eq "api.parishfinder.app" and http.request.uri.path eq
  "/feedback" and http.request.method eq "POST"`
- Rate: 20 requests per hour, per IP (generous next to the app's real usage —
  the in-Worker limit of 5/hour stays as the tighter, correctness-level check)
- Action: Block, 1 hour

Note this only covers traffic arriving via the custom domain. Requests to the
legacy `workers.dev` hostname — i.e. every already-installed beta — still bypass
the edge rule and are caught only by the in-Worker D1 limit. That's the residual
gap until the legacy route is retired.

## 3. Route the Worker through `api.parishfinder.app` · **DONE 2026-08-02**

`worker/wrangler.toml` now declares `workers_dev = true` alongside a
`custom_domain` route for `api.parishfinder.app`, and the Worker is deployed.
Cloudflare provisioned the DNS
record and certificate automatically — no dashboard step was needed after all.

Verified: `https://api.parishfinder.app/admin` returns 401 (Basic Auth
challenge, so the Worker is executing), and the legacy
`https://introibo-feedback.mfgarvin.workers.dev/admin` returns 401 as well —
**both hostnames serve the same Worker.** The legacy route must stay enabled;
shipped beta APKs point at it.

`lib/config/feedback_endpoint.dart` now defaults to
`https://api.parishfinder.app/feedback`, so new builds use the custom domain.
Installed betas are unaffected.

## 4. Security headers on the static site · **DONE 2026-08-02**

`site/_headers` is written. Pages reads it from the build output directory and
applies it to every response; it ships on the next push to `main` (the site is
Git-deployed now — see [`pages-git-deploy.md`](pages-git-deploy.md)).

Pages already served `x-content-type-options: nosniff` and
`referrer-policy: strict-origin-when-cross-origin`. The file adds a strict CSP,
HSTS (`max-age=31536000; includeSubDomains`, **no `preload`** — preloading is
effectively irreversible and deserves its own decision), and `X-Frame-Options`.

The CSP is `default-src 'self'` with `img-src` extended for `data:` and
everything else locked down (`connect-src`, `object-src`, `frame-ancestors`,
`base-uri`, `form-action` all `'none'`). This is only possible because the site
makes zero external requests.

**`script-src 'self'`, not `'none'`.** `site/theme.js` is the light/dark switch
and `'none'` would silently kill the toggle. It's a same-origin `<script src>`
with no inline code, so `'self'` covers it — verified: neither `index.html` nor
`privacy.html` contains an inline `<script>`, a `<style>` block, or a `style=`
attribute. `theme.js` sets attributes and `innerHTML`, which CSP doesn't
restrict.

Re-check this if the site ever gains inline script or a third-party embed; those
need `'unsafe-inline'` (avoid) or a nonce (fine) respectively.

**After the next push, verify it landed:**

```bash
curl -sI https://parishfinder.app/ | grep -iE 'content-security-policy|strict-transport'
```

## 5. Redirect `parishfinder.pages.dev` → `parishfinder.app` · TODO (dashboard)

Not security — SEO. The preview alias is publicly reachable and will get indexed
as duplicate content. Rules → Redirect Rules, one rule:

- Match: `http.host eq "parishfinder.pages.dev"`
- Action: Dynamic redirect, 301, to
  `concat("https://parishfinder.app", http.request.uri.path)`

The Pages project kept its name through the Git-integration switch, so the
hostname above is still correct.

---

## Also worth knowing

Cloudflare Pages 308-redirects `/privacy.html` → `/privacy`, so the canonical
privacy URL for the Play listing is **`https://parishfinder.app/privacy`**. The
in-page links still point at `privacy.html` on purpose (host-portable, per
`site/README.md`) and resolve through the redirect.

Wrangler fails non-interactively with "More than one account available" — two
accounts are on the login. Set `CLOUDFLARE_ACCOUNT_ID` for the command; get the
id from `npx wrangler whoami`, which lists both.
