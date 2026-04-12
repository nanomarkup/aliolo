UPDATE cards
SET localized_data = jsonb_build_object('global', cards.localized_data->'global')
FROM subjects
WHERE cards.subject_id = subjects.id
  AND subjects.localized_data->'global'->>'name' = 'Dog Breeds';
