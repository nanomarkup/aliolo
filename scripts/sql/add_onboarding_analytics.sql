CREATE TABLE IF NOT EXISTS onboarding_analytics (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL,
  age_range TEXT,
  pillar_id INTEGER,
  last_slide_index INTEGER,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(session_id)
);
