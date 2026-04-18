INSERT INTO ui_translations (key, lang, value, updated_at) VALUES
  ('users', 'en', 'Users', CURRENT_TIMESTAMP),
  ('premium_only', 'en', 'Premium only', CURRENT_TIMESTAMP),
  ('fake_only', 'en', 'Fake only', CURRENT_TIMESTAMP),
  ('free_only', 'en', 'Free users', CURRENT_TIMESTAMP),
  ('personal_data', 'en', 'Personal data', CURRENT_TIMESTAMP),
  ('subscription_data', 'en', 'Subscription data', CURRENT_TIMESTAMP),
  ('no_users_found', 'en', 'No users found', CURRENT_TIMESTAMP)
ON CONFLICT(key, lang) DO UPDATE SET
  value = excluded.value,
  updated_at = CURRENT_TIMESTAMP;
