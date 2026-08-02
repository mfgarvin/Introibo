# ParishFinder Feedback Worker

Cloudflare Worker that accepts feedback submissions from the Flutter app and
stores them in a D1 database.

> The Worker, its URL, and the D1 database are still named `introibo-feedback`
> (the app's old name) — deliberately unchanged so the live endpoint the shipped
> app points at keeps working. Only the app's public name changed to ParishFinder.

**Status:** deployed and live at **`https://api.parishfinder.app`** (D1 db
`introibo-feedback`, account mfjgarvin@gmail.com).

The `introibo-feedback.mfgarvin.workers.dev` hostname was **retired 2026-08-02**
(`workers_dev = false`). Being on our own zone is what lets Cloudflare WAF and
rate-limiting rules cover the Worker at all — they're zone-scoped and can't touch
a `workers.dev` subdomain. Beta APKs built before that date point at the old URL
and can no longer submit feedback.

The app's `lib/config/feedback_endpoint.dart` points at the custom domain. The
one-time setup below is only needed to recreate the deployment from scratch; for day-to-day use you only need **Deploy** (to push
code changes) and **View feedback**.

## Endpoints

- `POST /feedback` — body: JSON shaped like `FeedbackBody` in `src/index.ts`.
  Returns `{ ok: true, id: N }` on success, `{ ok: false, error: "..." }` otherwise.
- `GET /healthz` — returns `{ ok: true }`.
- `GET /admin` — HTML dashboard to browse/filter feedback (Basic Auth).
- `GET /admin/data` — JSON feed the dashboard fetches (Basic Auth).
- `POST /admin/digest` — fire the Discord digest on demand, for testing (Basic Auth).

## Monitoring the feedback

Two ways, both driven by the Worker itself (no local wrangler auth needed):

### 1. Web dashboard — `/admin`

A single self-contained page that lists every submission with kind/parish/status
filters, free-text search, and expandable full detail. Open it in a browser:

```
https://api.parishfinder.app/admin
```

It's protected by **HTTP Basic Auth** — any username, password = the
`ADMIN_PASSWORD` secret. Set it once:

```bash
npx wrangler secret put ADMIN_PASSWORD      # paste a strong password
```

### 2. Daily Discord digest (Cron Trigger)

`wrangler.toml` schedules `scheduled()` at **12:00 UTC** (≈ 8am US Eastern). It
queries the last 24h of feedback and POSTs a summary to a Discord webhook — the
same push-to-webhook pattern the bulletin monitor uses. Quiet days still send a
one-line heartbeat so you know the pipeline is alive.

Configure the destination (and, optionally, a dashboard link included in the
message):

```bash
npx wrangler secret put DISCORD_WEBHOOK_URL   # Discord channel → Integrations → Webhooks → Copy URL
npx wrangler secret put DASHBOARD_URL         # optional, e.g. https://…workers.dev/admin
npx wrangler deploy                           # cron trigger is registered on deploy
```

Test it immediately without waiting for the cron (uses the same Basic-Auth password):

```bash
curl -u admin:$ADMIN_PASSWORD -X POST https://api.parishfinder.app/admin/digest
```

To change the time, edit `crons` in `wrangler.toml` (UTC) and redeploy.

## One-time setup

```bash
cd worker
npm install
npx wrangler login          # if you haven't already
npx wrangler d1 create introibo-feedback
```

Paste the returned `database_id` into `wrangler.toml`, then init the schema:

```bash
npm run db:init             # creates tables in the remote D1
npm run db:init-local       # creates tables in the local dev D1
```

## Develop locally

```bash
npm run dev                 # wrangler dev — local D1, hot reload
```

`npm run dev` serves on localhost. There is no `workers.dev` URL any more —
`workers_dev = false` in `wrangler.toml`, and the only public hostname is the
`api.parishfinder.app` custom-domain route declared alongside it.

## Deploy

```bash
npm run deploy
```

The hostname is declared in `wrangler.toml` (`workers_dev = false` plus the
`api.parishfinder.app` custom-domain route), so a deploy keeps it in place. The
app already points there — no URL to paste unless you change it.

`/admin*` sits behind **Cloudflare Access** (one-time PIN, single-address
policy), so `curl -u admin:… POST /admin/digest` no longer works without an
Access service token. The daily cron is unaffected — `scheduled()` runs inside
the Worker and never crosses Access.

## Inspect submissions (CLI)

For terminal use there's the bundled viewer, `logs.sh` — handy but note it needs
a local authenticated wrangler session (`npx wrangler login`) plus `python3`, so
for casual checking the `/admin` dashboard above is usually less friction. If
`logs.sh` errors out, it's almost always an expired login; it now says so
explicitly instead of printing a Python traceback.

```bash
./worker/logs.sh              # interactive menu (recent / by kind / detail / stats)
```

One-shot commands (skip the menu):

```bash
./worker/logs.sh recent 20    # 20 most recent submissions (table)
./worker/logs.sh parish_data  # parish-data feedback only
./worker/logs.sh general      # general app feedback only
./worker/logs.sh show 42      # full detail of submission #42
./worker/logs.sh stats        # counts by kind + last-24h count
```

It can be run from anywhere in the repo (it `cd`s into `worker/` itself) and
uses the pinned local wrangler, falling back to `npx wrangler`.

Or query D1 directly:

```bash
npx wrangler d1 execute introibo-feedback --remote \
  --command "SELECT id, created_at, kind, parish_name, substr(body, 1, 60) AS snippet FROM feedback ORDER BY id DESC LIMIT 20"
```

## Rate limiting

5 submissions per IP per hour, enforced by a `feedback_rate` ledger table.
Adjust `RATE_LIMIT_PER_HOUR` in `src/index.ts`.
