-- Run this after add_onboarding_user_link.sql if the previous user_id column
-- was already added to onboarding_analytics. SQLite/D1 removes columns safely
-- by rebuilding the table.

DROP INDEX IF EXISTS idx_onboarding_analytics_user_id;
DROP INDEX IF EXISTS idx_onboarding_analytics_user_email;

ALTER TABLE onboarding_analytics RENAME TO onboarding_analytics_old;

CREATE TABLE onboarding_analytics (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL,
  user_email TEXT,
  age_range TEXT,
  pillar_id INTEGER,
  last_slide_index INTEGER,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(session_id)
);

INSERT INTO onboarding_analytics (
  id,
  session_id,
  user_email,
  age_range,
  pillar_id,
  last_slide_index,
  created_at,
  updated_at
)
SELECT
  oa.id,
  oa.session_id,
  COALESCE(oa.user_email, p.email),
  oa.age_range,
  oa.pillar_id,
  oa.last_slide_index,
  oa.created_at,
  oa.updated_at
FROM onboarding_analytics_old oa
LEFT JOIN profiles p ON p.id = oa.user_id;

DROP TABLE onboarding_analytics_old;

CREATE INDEX IF NOT EXISTS idx_onboarding_analytics_user_email
ON onboarding_analytics(user_email);
