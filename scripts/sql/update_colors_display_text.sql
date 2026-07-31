UPDATE cards
SET
  display_text = trim(substr(answer, instr(answer, ', #') + 2)),
  answer = trim(substr(answer, 1, instr(answer, ', #') - 1))
WHERE subject_id IN (
  SELECT id
  FROM subjects
  WHERE lower(name) = 'colors'
)
AND instr(answer, ', #') > 0;

UPDATE cards
SET display_text = '#' || display_text
WHERE subject_id IN (
  SELECT id
  FROM subjects
  WHERE lower(name) = 'colors'
)
AND display_text NOT LIKE '#%'
AND display_text <> '';
