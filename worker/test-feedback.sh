#!/usr/bin/env bash
#
# Contract tests for the feedback endpoint (POST /feedback) — the same request
# the app's lib/services/feedback_client.dart makes. Exercises both feedback
# kinds and the validation error paths, then reports PASS/FAIL.
#
#   ./worker/test-feedback.sh            # run the contract tests
#   ./worker/test-feedback.sh ratelimit # separately verify the 5/hour 429 cap
#   ./worker/test-feedback.sh list       # show test rows currently in D1 (needs wrangler login)
#   ./worker/test-feedback.sh cleanup     # delete this script's test rows from D1 (needs wrangler login)
#
# IMPORTANT: submissions land in the LIVE D1 database. Every test body carries
# the marker below so `cleanup` can find and delete exactly these rows.
#
# Env:
#   FEEDBACK_ENDPOINT   override the target (default: production worker)
#
# Deps: curl, python3 (for JSON escaping). cleanup/list also need wrangler.

set -euo pipefail

ENDPOINT="${FEEDBACK_ENDPOINT:-https://introibo-feedback.mfgarvin.workers.dev/feedback}"
MARKER="[[QA-SONNET]]"                     # tag on every test row → targeted cleanup
DB="introibo-feedback"
cd "$(dirname "$0")"                        # so wrangler finds wrangler.toml

if [ -x "./node_modules/.bin/wrangler" ]; then WRANGLER="./node_modules/.bin/wrangler"; else WRANGLER="npx --yes wrangler"; fi

pass=0; fail=0
green() { printf '\033[32m%s\033[0m' "$1"; }
red()   { printf '\033[31m%s\033[0m' "$1"; }

# jbody <<'JSON' … JSON  → compact one-line JSON (also validates it)
jbody() { python3 -c 'import sys,json; print(json.dumps(json.load(sys.stdin)))'; }

# post <name> <expect_status> <expect_substr> <json>
# Sends the JSON, checks HTTP status and that the response body contains substr.
post() {
  local name="$1" want_status="$2" want_sub="$3" json="$4"
  local resp status sub
  resp="$(curl -sS -m 15 -w $'\n%{http_code}' \
            -H 'Content-Type: application/json' \
            -X POST "$ENDPOINT" --data "$json" || true)"
  status="${resp##*$'\n'}"
  sub="${resp%$'\n'*}"
  if [ "$status" = "$want_status" ] && printf '%s' "$sub" | grep -q "$want_sub"; then
    printf '  %s %s (%s)\n' "$(green PASS)" "$name" "$status"
    pass=$((pass + 1))
  else
    printf '  %s %s — wanted %s + "%s", got %s: %s\n' \
      "$(red FAIL)" "$name" "$want_status" "$want_sub" "$status" "$sub"
    fail=$((fail + 1))
  fi
}

# Bodies mirror what feedback_client.dart sends. platform=qa-script marks them
# further; the MARKER in body text is the cleanup key.
run_contract() {
  echo "Target: $ENDPOINT"
  echo "Marker: $MARKER  (cleanup deletes rows whose body contains this)"
  echo

  echo "Valid submissions (each consumes 1 of the 5/hour rate budget):"
  post "general feedback" 200 '"ok":true' "$(jbody <<JSON
{"kind":"general","body":"$MARKER general feedback smoke test — please ignore","reply_email":"qa@example.com","app_version":"qa","build_number":"0","platform":"qa-script"}
JSON
)"

  post "parish_data (accurate)" 200 '"ok":true' "$(jbody <<JSON
{"kind":"parish_data","body":"$MARKER User confirmed this parish data is accurate.","parish_name":"QA Test Parish","parish_id":"0000","status":"accurate","platform":"qa-script"}
JSON
)"

  post "parish_data (issue+categories)" 200 '"ok":true' "$(jbody <<JSON
{"kind":"parish_data","body":"$MARKER Mass time looks wrong","parish_name":"QA Test Parish","parish_id":"0000","status":"issue","issue_categories":["mass_times","other"],"platform":"qa-script"}
JSON
)"

  echo
  echo "Validation errors (rejected before the rate-limit check — no budget spent):"
  post "missing body → 400" 400 'kind and body are required' "$(jbody <<JSON
{"kind":"general","platform":"qa-script"}
JSON
)"

  post "unknown kind → 400" 400 'unknown kind' "$(jbody <<JSON
{"kind":"bogus","body":"$MARKER should be rejected","platform":"qa-script"}
JSON
)"

  # Deliberately malformed JSON (not run through jbody).
  post "invalid json → 400" 400 'invalid json' '{not valid json'

  echo
  printf 'Result: %s passed, %s failed\n' "$(green "$pass")" "$([ "$fail" -eq 0 ] && green 0 || red "$fail")"
  echo "Verify the 3 valid rows in the /admin dashboard or: ./test-feedback.sh list"
  echo "Then remove them with: ./test-feedback.sh cleanup"
  [ "$fail" -eq 0 ]
}

# Fires valid submissions until the 5/hour per-IP cap returns 429. Kept separate
# because it intentionally spends the whole rate budget and writes several rows.
run_ratelimit() {
  echo "Rate-limit probe against $ENDPOINT (expects a 429 by the 6th valid POST)."
  echo "This spends the hourly budget and writes test rows — run 'cleanup' after."
  local hit=0
  for i in $(seq 1 6); do
    local resp status
    resp="$(curl -sS -m 15 -w $'\n%{http_code}' -H 'Content-Type: application/json' \
              -X POST "$ENDPOINT" \
              --data "$(jbody <<JSON
{"kind":"general","body":"$MARKER rate-limit probe #$i","platform":"qa-script"}
JSON
)" || true)"
    status="${resp##*$'\n'}"
    printf '  POST #%s → %s\n' "$i" "$status"
    [ "$status" = "429" ] && hit=1 && break
  done
  if [ "$hit" = 1 ]; then printf '  %s rate limit enforced\n' "$(green PASS)"; else
    printf '  %s never saw a 429 (limit may already be partly spent, or cap changed)\n' "$(red WARN)"; fi
}

case "${1:-run}" in
  run)       run_contract ;;
  ratelimit) run_ratelimit ;;
  list)      $WRANGLER d1 execute "$DB" --remote --command \
               "SELECT id, created_at, kind, status, substr(body,1,50) AS snippet FROM feedback WHERE body LIKE '%${MARKER}%' ORDER BY id DESC" ;;
  cleanup)   $WRANGLER d1 execute "$DB" --remote --command \
               "DELETE FROM feedback WHERE body LIKE '%${MARKER}%'" \
               && echo "Deleted all rows tagged ${MARKER}." ;;
  *) echo "usage: $0 [run | ratelimit | list | cleanup]"; exit 1 ;;
esac
