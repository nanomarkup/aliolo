UPDATE cards
SET renderer = CASE subject_id
  WHEN 'de04da1c-9820-4e61-ae6b-bc7ed07eeb93' THEN 'addition_emoji'
  WHEN '5e81da1f-f92c-44d2-b3cd-f921d05425df' THEN 'addition_number'
  WHEN 'ce04da1c-9820-4e61-ae6b-bc7ed07eeb93' THEN 'subtraction_emoji'
  WHEN 'f59a0f9c-5d6d-4f2d-b426-eb9ca6bf2782' THEN 'subtraction_number'
  ELSE renderer
END,
updated_at = CURRENT_TIMESTAMP
WHERE subject_id IN (
  'de04da1c-9820-4e61-ae6b-bc7ed07eeb93',
  '5e81da1f-f92c-44d2-b3cd-f921d05425df',
  'ce04da1c-9820-4e61-ae6b-bc7ed07eeb93',
  'f59a0f9c-5d6d-4f2d-b426-eb9ca6bf2782'
);
