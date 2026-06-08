#!/usr/bin/env bash
#
# Interactive viewer for Introibo feedback submissions stored in the
# Cloudflare D1 database. Run from anywhere:
#
#   ./worker/logs.sh            # interactive menu
#   ./worker/logs.sh recent 20  # one-shot: 20 most recent rows
#   ./worker/logs.sh show 5     # one-shot: full detail of row id 5
#
# Requires: wrangler (resolved from worker/node_modules or PATH), python3,
# and an authenticated wrangler session (`wrangler login`).

set -euo pipefail

# Always run relative to the worker dir so wrangler finds wrangler.toml.
cd "$(dirname "$0")"

DB="introibo-feedback"

# Prefer the pinned local wrangler; fall back to npx.
if [ -x "./node_modules/.bin/wrangler" ]; then
  WRANGLER="./node_modules/.bin/wrangler"
else
  WRANGLER="npx --yes wrangler"
fi

# Run a SQL query against remote D1 and emit the results array as JSON.
# Strips wrangler's banner by asking for --json and parsing only stdout.
query() {
  local sql="$1"
  $WRANGLER d1 execute "$DB" --remote --json --command "$sql" 2>/dev/null \
    | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)[0]['results']))"
}

# Python formatters are loaded into variables so the rows can be piped in on
# stdin (a `python3 - <<HEREDOC` would consume stdin for the program itself).
read -r -d '' TABLE_PY <<'PY' || true
import sys, json
rows = json.load(sys.stdin)
if not rows:
    print("  (no rows)")
    sys.exit(0)
def cell(v, n):
    s = "" if v is None else str(v).replace("\n", " ")
    return (s[: n - 1] + "…") if len(s) > n else s.ljust(n)
hdr = f'{"ID":<4} {"WHEN (UTC)":<20} {"KIND":<12} {"PARISH":<22} {"STATUS":<9} BODY'
print(hdr)
print("-" * len(hdr))
for r in rows:
    print(f'{cell(r.get("id"),4)} {cell(r.get("created_at"),20)} '
          f'{cell(r.get("kind"),12)} {cell(r.get("parish_name"),22)} '
          f'{cell(r.get("status"),9)} {cell(r.get("body"),40)}')
PY

read -r -d '' DETAIL_PY <<'PY' || true
import sys, json
rows = json.load(sys.stdin)
if not rows:
    print("  (no row with that id)")
    sys.exit(0)
r = rows[0]
for k in ("id","created_at","kind","parish_name","parish_id","status",
          "issue_categories","reply_email","app_version","build_number",
          "platform","client_ip","body"):
    print(f'  {k:<16}: {r.get(k)}')
PY

# Pretty-print a JSON array of rows as an aligned table (selected columns).
print_table() { python3 -c "$TABLE_PY"; }

# Pretty-print a single row as a key/value block.
print_detail() { python3 -c "$DETAIL_PY"; }

esc() { printf '%s' "$1" | sed "s/'/''/g"; }  # escape single quotes for SQL

cmd_recent() {
  local n="${1:-20}"
  echo
  echo "Most recent $n submissions:"
  query "SELECT id, created_at, kind, parish_name, status, body
         FROM feedback ORDER BY id DESC LIMIT $n" | print_table
}

cmd_kind() {
  local kind; kind="$(esc "$1")"; local n="${2:-20}"
  echo
  echo "Most recent $n '$1' submissions:"
  query "SELECT id, created_at, kind, parish_name, status, body
         FROM feedback WHERE kind='$kind' ORDER BY id DESC LIMIT $n" | print_table
}

cmd_show() {
  local id; id="$(esc "$1")"
  echo
  echo "Submission #$1:"
  query "SELECT * FROM feedback WHERE id='$id'" | print_detail
}

cmd_stats() {
  echo
  echo "Counts by kind:"
  query "SELECT kind, COUNT(*) AS n FROM feedback GROUP BY kind ORDER BY n DESC" \
    | python3 -c "import sys,json;[print(f'  {r[\"kind\"]:<14} {r[\"n\"]}') for r in json.load(sys.stdin)] or print('  (empty)')"
  echo "Last 24h:"
  query "SELECT COUNT(*) AS n FROM feedback WHERE created_at > datetime('now','-1 day')" \
    | python3 -c "import sys,json;print('  ',json.load(sys.stdin)[0]['n'],'submissions')"
}

# One-shot mode: dispatch on the first arg and exit.
if [ "$#" -gt 0 ]; then
  case "$1" in
    recent) cmd_recent "${2:-20}" ;;
    general|parish_data) cmd_kind "$1" "${2:-20}" ;;
    show) [ -n "${2:-}" ] || { echo "usage: $0 show <id>"; exit 1; }; cmd_show "$2" ;;
    stats) cmd_stats ;;
    *) echo "usage: $0 [recent N | general | parish_data | show ID | stats]"; exit 1 ;;
  esac
  exit 0
fi

# Interactive menu.
while true; do
  cat <<MENU

╔════════════════════════════════════════════╗
║         Introibo Feedback Log Viewer        ║
╠════════════════════════════════════════════╣
║  1) Recent submissions (all)                ║
║  2) Parish data feedback only               ║
║  3) General app feedback only               ║
║  4) Show one submission in full (by id)     ║
║  5) Stats                                   ║
║  q) Quit                                    ║
╚════════════════════════════════════════════╝
MENU
  read -rp "Choose: " choice
  case "$choice" in
    1) read -rp "How many? [20]: " n; cmd_recent "${n:-20}" ;;
    2) cmd_kind parish_data 30 ;;
    3) cmd_kind general 30 ;;
    4) read -rp "Submission id: " id; [ -n "$id" ] && cmd_show "$id" ;;
    5) cmd_stats ;;
    q|Q) echo "Bye."; exit 0 ;;
    *) echo "Unknown option." ;;
  esac
done
