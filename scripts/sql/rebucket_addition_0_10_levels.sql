UPDATE cards
SET level = CASE
  WHEN CAST(answer AS INTEGER) <= 5 THEN 1
  ELSE 2
END,
updated_at = CURRENT_TIMESTAMP
WHERE subject_id = 'de04da1c-9820-4e61-ae6b-bc7ed07eeb93';
