UPDATE subjects
SET name = 'Numbers',
    visual_template = 'generic',
    updated_at = CURRENT_TIMESTAMP
WHERE id = 'bc354f43-f9be-42a9-a7bc-ac400bd5e310';

UPDATE cards
SET subject_id = 'bc354f43-f9be-42a9-a7bc-ac400bd5e310',
    level = CASE
      WHEN CAST(answer AS INTEGER) <= 10 THEN 1
      ELSE 2
    END,
    updated_at = CURRENT_TIMESTAMP
WHERE subject_id IN (
  'bc354f43-f9be-42a9-a7bc-ac400bd5e310',
  'cb04da1c-9820-4e61-ae6b-bc7ed07eeb93'
);

UPDATE user_subjects AS us
SET subject_id = 'bc354f43-f9be-42a9-a7bc-ac400bd5e310'
WHERE subject_id = 'cb04da1c-9820-4e61-ae6b-bc7ed07eeb93'
  AND NOT EXISTS (
    SELECT 1
    FROM user_subjects existing
    WHERE existing.user_id = us.user_id
      AND COALESCE(existing.collection_id, '') = COALESCE(us.collection_id, '')
      AND existing.subject_id = 'bc354f43-f9be-42a9-a7bc-ac400bd5e310'
  );

DELETE FROM user_subjects
WHERE subject_id = 'cb04da1c-9820-4e61-ae6b-bc7ed07eeb93';

DELETE FROM subjects
WHERE id = 'cb04da1c-9820-4e61-ae6b-bc7ed07eeb93';
