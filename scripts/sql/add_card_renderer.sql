ALTER TABLE cards ADD COLUMN renderer TEXT NOT NULL DEFAULT 'generic';

UPDATE cards
SET renderer = CASE
  WHEN test_mode IN ('addition', 'subtraction', 'multiplication', 'division', 'counting', 'numbers') THEN 'math'
  WHEN test_mode = 'colors' THEN 'colors'
  ELSE 'generic'
END;
