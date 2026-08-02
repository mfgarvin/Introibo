# Security hardening — status

Scoped 2026-08-01, worked 2026-08-02. Items **1, 3, and 4 are done.** Remaining:
item 2 (edge rate-limit on `/feedback`) and item 5 (`pages.dev` redirect), both
dashboard work — wrangler's OAuth token carries `zone (read)` but no WAF scope —
plus item 6, retiring the legacy `workers.dev` route, which is a repo change.

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

## 1. Protect `/admin*` — **DONE 2026-08-02**

Cloudflare Access is live on `api.parishfinder.app/admin` with a one-time PIN
policy. Verified: `/admin` no longer returns the Worker's `401` (Access answers
first), `POST /feedback` still returns the Worker's own JSON validation error
(`kind and body are required`) and so is correctly outside the protected path,
and a login attempt from a non-allowed address is denied after the PIN.

**The policy is the authorization, not the PIN.** The PIN only proves control of
whatever address was typed; anyone can complete it. What keeps others out is the
policy's `Include → Emails → mfjgarvin@gmail.com`. Two settings silently undo
that and both are easy mis-clicks — `Include → Everyone`, and the domain-suffix
rule `Emails ending in @gmail.com` (i.e. every Gmail account). If this is ever
rebuilt, re-run the wrong-email test rather than reading the config.

The original gap, for the record:

**The gap:** Basic Auth was the only thing guarding the dashboard, and unlike
`/feedback` (5/hour/IP, enforced in D1) the admin routes have **no throttle at
all**. The password can be ground down unmetered. What's behind it is submitter
email addresses — PII under our own privacy policy.

The auth code itself is fine (`worker/src/index.ts:157` — fails closed when
`ADMIN_PASSWORD` is unset, timing-safe compare, admin routes correctly excluded
from the permissive CORS). The problem is the absence of a brute-force limit,
not the check.

**Decided fix: Cloudflare Access**, with the **one-time PIN** login method.
Free for up to 50 users, removes the shared password as an attack surface,
needs no code change. Zero Trust is already set up on the account. The
prerequisite (item 3) is done, so this is ready to do.

A Google identity provider was considered and **rejected** (2026-08-02): plain
Google sign-in would work with a personal `@gmail.com`, but it costs a Google
Cloud OAuth client, a consent screen that expires out of testing mode, and a
second place for login to break — not worth it for one admin. One-time PIN it
is.

1. Zero Trust → Access → Applications → **Add an application** → *Self-hosted*
2. Application name: `ParishFinder admin`; session duration: 24h is fine.
3. Public hostname: subdomain `api`, domain `parishfinder.app`, **path `admin`**
4. Policy: name `Owner`, action **Allow**, include → **Emails** →
   `mfjgarvin@gmail.com`.
5. Identity: leave the one-time PIN provider on; add nothing else.

**Step 3 is the one that can break the product.** Access matches on path prefix,
so `admin` covers `/admin`, `/admin/data`, and `/admin/digest`. Leaving the path
**blank** protects the whole hostname — including `POST /feedback`, which would
start returning an HTML login page to every new build of the app.

Verify in this order:

```bash
# admin: expect an Access redirect / login HTML, no longer a 401
curl -sI https://api.parishfinder.app/admin | head -3

# feedback: must still be a plain JSON API. HTML here means the path scope is wrong.
curl -s -X POST https://api.parishfinder.app/feedback \
  -H 'content-type: application/json' -d '{}' | head -c 200
```

Then open `/admin` in a private window and confirm the PIN flow appears.

**Keep the Basic Auth check in the Worker** as defence in depth — it is also the
fallback if Access is ever misconfigured. Don't remove it.

Two consequences to expect:

- `curl -u admin:… -X POST …/admin/digest` (in `worker/README.md`) stops working
  through the custom domain; Access intercepts it before the Worker runs. Use an
  Access **service token** (`CF-Access-Client-Id` / `CF-Access-Client-Secret`
  headers) or just wait for the cron. The daily digest itself is unaffected —
  `scheduled()` runs inside the Worker and never crosses Access.
- Access is bound to a hostname, so `/admin` on the legacy
  `introibo-feedback.mfgarvin.workers.dev` remains Basic-Auth-only. A Worker-side
  host check was considered and **declined** (2026-08-02): the legacy route is
  being retired shortly, with few beta APKs in the wild, so the guard would be
  obsolete before it paid for itself. Revisit only if that retirement slips.

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

## 6. Retire the legacy `workers.dev` route · TODO (soon)

Flagged 2026-08-02 as imminent — few beta APKs are out, and closing this route
resolves the residual gaps in items 1 and 2 at a stroke (edge rules and Access
both stop being bypassable). When the time comes:

1. Set `workers_dev = false` in `worker/wrangler.toml`, `wrangler deploy`.
2. Confirm `https://api.parishfinder.app/feedback` still answers and the
   `workers.dev` hostname no longer resolves to the Worker.
3. Any beta install that hasn't updated will silently fail to submit feedback —
   that's the accepted cost. The app surfaces a clear error on failure.

---

## Also worth knowing

Cloudflare Pages 308-redirects `/privacy.html` → `/privacy`, so the canonical
privacy URL for the Play listing is **`https://parishfinder.app/privacy`**. The
in-page links still point at `privacy.html` on purpose (host-portable, per
`site/README.md`) and resolve through the redirect.

Wrangler fails non-interactively with "More than one account available" — two
accounts are on the login. Set `CLOUDFLARE_ACCOUNT_ID` for the command; get the
id from `npx wrangler whoami`, which lists both.
