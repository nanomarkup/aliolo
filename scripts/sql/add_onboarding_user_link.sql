ALTER TABLE onboarding_analytics ADD COLUMN user_email TEXT;

CREATE INDEX IF NOT EXISTS idx_onboarding_analytics_user_email
ON onboarding_analytics(user_email);
