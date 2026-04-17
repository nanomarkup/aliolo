UPDATE cards
SET display_text = '',
    display_texts = '{}',
    updated_at = CURRENT_TIMESTAMP
WHERE subject_id IN (
  '5e81da1f-f92c-44d2-b3cd-f921d05425df',
  'f59a0f9c-5d6d-4f2d-b426-eb9ca6bf2782'
);
