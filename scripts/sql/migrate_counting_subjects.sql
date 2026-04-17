ALTER TABLE subjects ADD COLUMN visual_template TEXT NOT NULL DEFAULT 'generic';

UPDATE subjects
SET name = 'Counting',
    visual_template = 'counting',
    updated_at = CURRENT_TIMESTAMP
WHERE id = '68232807-b9cd-4cff-872c-c398444f85e2';

UPDATE cards
SET level = CASE
  WHEN CAST(answer AS INTEGER) <= 5 THEN 1
  ELSE 2
END
WHERE subject_id = '68232807-b9cd-4cff-872c-c398444f85e2';

DELETE FROM user_subjects
WHERE subject_id = 'c3548727-65f4-4e0c-939c-56135b4eb543';

DELETE FROM cards
WHERE subject_id = 'c3548727-65f4-4e0c-939c-56135b4eb543';

DELETE FROM subjects
WHERE id = 'c3548727-65f4-4e0c-939c-56135b4eb543';
