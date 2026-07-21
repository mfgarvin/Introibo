# Feedback Test Plan

A guide for exercising ParishFinder's feedback features end-to-end — from the
in-app UI down to the Cloudflare Worker, D1 storage, and the two monitoring
surfaces (admin dashboard + Discord digest). Written to be runnable by an agent
(e.g. a Sonnet subagent) or a human.

> ⚠️ **All feedback writes to the LIVE D1 database** — there is no staging
> endpoint. Every test payload here carries the marker **`[[QA-SONNET]]`** so it
> can be found and deleted afterward. Always finish with the cleanup step.

## The two feedback functions

| # | Function | Where in the app | Client call (`lib/services/feedback_client.dart`) |
|---|----------|------------------|---------------------------------------------------|
| 1 | **General app feedback** | Home → church icon (top bar) → **Feedback** → text box (+ optional email) → **Submit Feedback** (`lib/main.dart:1837`) | `submitFeedback(kind:'general', body, replyEmail)` |
| 2 | **Parish data feedback** | Any parish detail page → **"Is this information accurate?"** card → bottom sheet → pick Yes/No (+ issue tags if No) → **Confirm Data / Submit Feedback** (`lib/pages/parish_detail_page.dart:1017`) | `submitFeedback(kind:'parish_data', body, parishName, parishId, status, issueCategories)` |

Server contract lives in `worker/src/index.ts` (`handleFeedback`). Validation
order matters: payload-size → JSON parse → `kind`/`body` required → `kind` in
{`general`,`parish_data`} → **rate limit (5/IP/hour)** → insert. Validation
failures return `400` *before* the rate-limit check, so they don't spend budget.

`status` is `accurate` | `issue`. `issue_categories` (issue only) come from a
fixed list: `mass_times`, `confession`, `adoration`, `address`, `phone`,
`website`, `other`.

## Part A — Endpoint contract tests (fast, automated)

This is the backbone. It hits `POST /feedback` exactly like the app client and
checks status codes + response bodies.

```bash
cd worker
./test-feedback.sh            # 3 valid submissions + 3 validation-error cases
```

Expect `Result: 6 passed, 0 failed`. It submits one `general`, two `parish_data`
(accurate + issue), and verifies `400`s for missing body / unknown kind /
malformed JSON.

Optional — verify the rate limiter (spends the whole hourly budget, writes ~6
rows):

```bash
./test-feedback.sh ratelimit  # expects a 429 by the 6th valid POST
```

Point it at a local `wrangler dev` instead of production to avoid touching prod:

```bash
FEEDBACK_ENDPOINT=http://localhost:8787/feedback ./test-feedback.sh
```

## Part B — In-app UI flows (the real thing)

Run the app and drive both flows so the UI, client, and validation are all
exercised. Use a debug build so `flutter run` is quick.

```bash
flutter run -d linux          # or -d chrome / a device
```

**Flow 1 — General feedback**
1. On Home, tap the church icon in the top bar → **Feedback**.
2. Submit with the box empty → expect a red **"Please enter your feedback"**
   snackbar (client-side guard, no network call).
3. Enter body `` [[QA-SONNET]] general via UII `` and an email, tap
   **Submit Feedback** → expect the green **"Feedback sent — thank you!"**
   snackbar and the sheet closes.

**Flow 2 — Parish data feedback**
1. Open any parish (search on Home, or a Nearby/Home-parish tile).
2. Tap the **"Is this information accurate?"** card.
3. **Accurate path:** choose **Yes** → **Confirm Data** → expect green
   **"Thanks for the feedback!"** and the sheet closes. (Sends
   `status:'accurate'`, no categories.)
4. **Issue path:** reopen, choose **No**, submit with **no** issue selected →
   expect red **"Please select at least one issue"**. Then select e.g.
   **Mass Times** + add a comment containing `[[QA-SONNET]]`, submit → green
   confirmation. (Sends `status:'issue'`, `issue_categories:['mass_times']`.)

> The UI submissions won't carry the marker unless you type it into the body.
> Include `[[QA-SONNET]]` in the free-text so cleanup catches them too. The
> parish-data *accurate* path has a fixed body ("User confirmed …") you can't
> edit — note its `id` from the dashboard for manual cleanup, or accept it as a
> real-looking row.

**Offline / error path (optional):** point the build at a bad endpoint and
confirm the failure surfaces instead of silently succeeding:

```bash
flutter run --dart-define=FEEDBACK_ENDPOINT=https://introibo-feedback.example.workers.dev/feedback
```

`feedbackEndpointConfigured` is false for `example.workers.dev`, so submissions
should short-circuit with **"Feedback endpoint not configured yet …"**.

## Part C — Verify it landed & monitoring works

1. **Admin dashboard:** open `https://introibo-feedback.mfgarvin.workers.dev/admin`
   (Basic Auth, password = `ADMIN_PASSWORD`). The `[[QA-SONNET]]` rows should
   appear; use the text filter to isolate them, expand one to check every field
   (kind, status, issue_categories, reply_email, platform).
2. **Digest:** trigger the Discord digest on demand and confirm the message
   arrives in the channel:
   ```bash
   curl -u admin:'<ADMIN_PASSWORD>' -X POST \
     https://introibo-feedback.mfgarvin.workers.dev/admin/digest
   ```
   It should summarize the last 24h (your test rows) and post to the webhook.
3. **CLI (optional):** `./worker/logs.sh recent 10` (needs `wrangler login`).

## Part D — Cleanup (required)

Remove every row this plan created:

```bash
cd worker
./test-feedback.sh list       # preview the tagged rows
./test-feedback.sh cleanup    # DELETE … WHERE body LIKE '%[[QA-SONNET]]%'
```

Both need an authenticated wrangler session (`npx wrangler login`). For the
fixed-body "accurate" UI rows that lack the marker, delete by id:

```bash
npx wrangler d1 execute introibo-feedback --remote \
  --command "DELETE FROM feedback WHERE id IN (<ids from dashboard>)"
```

## Pass criteria

- [ ] `./test-feedback.sh` → 6/6 pass.
- [ ] Both UI flows show the correct green success / red validation snackbars.
- [ ] All `[[QA-SONNET]]` rows visible in `/admin` with correct fields.
- [ ] Manual digest posts to Discord.
- [ ] Cleanup leaves no `[[QA-SONNET]]` rows (`list` returns none).
