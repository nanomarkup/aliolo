ALTER TABLE profiles ADD COLUMN test_mode TEXT DEFAULT 'question_to_answer';
UPDATE profiles
SET test_mode = 'question_to_answer'
WHERE test_mode IS NULL OR TRIM(test_mode) = '';
