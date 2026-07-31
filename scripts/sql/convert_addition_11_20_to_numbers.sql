UPDATE cards
SET display_text = answer,
    updated_at = CURRENT_TIMESTAMP
WHERE subject_id = '5e81da1f-f92c-44d2-b3cd-f921d05425df';
