INSERT INTO ui_translations (key, lang, value, updated_at) VALUES
  ('licenses_intro_title', 'en', 'Aliolo License and Package Notices', CURRENT_TIMESTAMP),
  ('licenses_intro_desc', 'en', 'Aliolo''s commercial license appears first. Third-party package licenses follow below.', CURRENT_TIMESTAMP),
  ('licenses_aliolo_section_title', 'en', 'Aliolo Commercial License', CURRENT_TIMESTAMP),
  ('licenses_aliolo_subtitle', 'en', 'Proprietary software and premium access terms', CURRENT_TIMESTAMP),
  ('licenses_third_party_section_title', 'en', 'Third-Party Package Licenses', CURRENT_TIMESTAMP)
ON CONFLICT(key, lang) DO UPDATE SET
  value = excluded.value,
  updated_at = CURRENT_TIMESTAMP;
