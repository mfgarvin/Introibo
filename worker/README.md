# Introibo Feedback Worker

Cloudflare Worker that accepts feedback submissions from the Flutter app and
stores them in a D1 database.

## Endpoints

- `POST /feedback` — body: JSON shaped like `FeedbackBody` in `src/index.ts`.
  Returns `{ ok: true, id: N }` on success, `{ ok: false, error: "..." }` otherwise.
- `GET /healthz` — returns `{ ok: true }`.

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

The worker URL on workers.dev will be of the form
`https://introibo-feedback.<your-account-subdomain>.workers.dev` after the
first `wrangler deploy`.

## Deploy

```bash
npm run deploy
```

Then take the printed URL and paste it into
`lib/config/feedback_endpoint.dart` in the Flutter app.

## Inspect submissions

```bash
npx wrangler d1 execute introibo-feedback --remote \
  --command "SELECT id, created_at, kind, parish_name, substr(body, 1, 60) AS snippet FROM feedback ORDER BY id DESC LIMIT 20"
```

## Rate limiting

5 submissions per IP per hour, enforced by a `feedback_rate` ledger table.
Adjust `RATE_LIMIT_PER_HOUR` in `src/index.ts`.
