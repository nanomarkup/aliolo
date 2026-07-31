ALTER TABLE profiles ADD COLUMN last_source_filter TEXT DEFAULT 'all';

UPDATE profiles
SET last_source_filter = 'all'
WHERE last_source_filter IS NULL;
