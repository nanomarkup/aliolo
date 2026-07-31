UPDATE cards
SET
  display_text = CASE
    WHEN COALESCE(NULLIF(display_text, ''), '') = '' THEN answer
    ELSE display_text
  END,
  renderer = CASE
    WHEN renderer = 'alphabet' THEN 'generic'
    ELSE renderer
  END
WHERE subject_id IN (
  SELECT id
  FROM subjects
  WHERE lower(name) = 'alphabet'
);

ALTER TABLE subjects DROP COLUMN subject_kind;
ALTER TABLE subjects DROP COLUMN visual_template;
