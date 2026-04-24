CREATE TABLE IF NOT EXISTS subject_usage_stats (
  subject_id TEXT REFERENCES subjects(id) ON DELETE CASCADE,
  mode TEXT NOT NULL CHECK(mode IN ('learn', 'test')),
  started_count INTEGER DEFAULT 0,
  completed_count INTEGER DEFAULT 0,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY(subject_id, mode)
);

CREATE INDEX IF NOT EXISTS idx_subject_usage_stats_started
ON subject_usage_stats(started_count DESC);
