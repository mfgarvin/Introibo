-- Single feedback table covers both kinds of submission:
--   kind='general'      → free-form app feedback (FeedbackPage)
--   kind='parish_data'  → parish data verification (parish detail sheet)
CREATE TABLE IF NOT EXISTS feedback (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at       TEXT NOT NULL DEFAULT (datetime('now')),
  kind             TEXT NOT NULL,                 -- 'general' | 'parish_data'
  parish_name      TEXT,                          -- present for parish_data
  parish_id        TEXT,
  status           TEXT,                          -- 'accurate' | 'issue' (parish_data)
  issue_categories TEXT,                          -- comma-separated tags
  reply_email      TEXT,
  body             TEXT NOT NULL,
  app_version      TEXT,
  build_number     TEXT,
  platform         TEXT,
  client_ip        TEXT,
  resolved_at      TEXT                           -- NULL = still open; set when triaged
);

-- Existing databases predate resolved_at. D1 has no ADD COLUMN IF NOT EXISTS, so
-- run this once by hand on an already-created database; it errors harmlessly
-- ("duplicate column name") if the column is already there:
--   wrangler d1 execute introibo-feedback --remote \
--     --command "ALTER TABLE feedback ADD COLUMN resolved_at TEXT"

CREATE INDEX IF NOT EXISTS idx_feedback_created
  ON feedback(created_at);

CREATE INDEX IF NOT EXISTS idx_feedback_resolved
  ON feedback(resolved_at);

CREATE INDEX IF NOT EXISTS idx_feedback_kind_created
  ON feedback(kind, created_at);

-- Rate-limit ledger. One row per submitting IP per minute window — we count
-- entries in the trailing hour at insert time to enforce a soft cap.
CREATE TABLE IF NOT EXISTS feedback_rate (
  client_ip   TEXT NOT NULL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_feedback_rate_ip_created
  ON feedback_rate(client_ip, created_at);
