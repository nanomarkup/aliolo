UPDATE cards
SET display_text = answer
WHERE subject_id IN (
  SELECT id
  FROM subjects
  WHERE lower(name) LIKE '%alphabet%'
);
