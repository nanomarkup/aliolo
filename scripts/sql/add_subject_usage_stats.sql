DROP TABLE IF EXISTS subject_usage_stats;

CREATE TABLE subject_usage_stats (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  subject_id TEXT REFERENCES subjects(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL,
  mode TEXT NOT NULL CHECK(mode IN ('learn', 'test')),
  completed BOOLEAN DEFAULT 0,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_subject_usage_stats_subject_user
ON subject_usage_stats(subject_id, user_id);

CREATE INDEX IF NOT EXISTS idx_subject_usage_stats_created
ON subject_usage_stats(created_at);
