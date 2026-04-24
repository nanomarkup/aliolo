CREATE INDEX IF NOT EXISTS idx_progress_user_next_review
ON progress(user_id, next_review);

CREATE INDEX IF NOT EXISTS idx_progress_user_hidden
ON progress(user_id, is_hidden);
