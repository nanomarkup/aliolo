WITH source_cards(card_id, color_name, hex_code, sort_order) AS (
  VALUES
    ('0cf1ddd3-c30c-454c-9baa-0baa7a420279', 'Silver', '#c0c0c0', 1),
    ('17ecaf4f-a730-4c46-a458-c66982656ba0', 'Maroon', '#800000', 2),
    ('2fc36e64-45c0-4b57-9764-d7cd31a37cc2', 'Purple', '#800080', 3),
    ('4760372b-d393-498e-a758-0d8e4b2f957a', 'Fuchsia', '#ff00ff', 4),
    ('31b86605-6e39-48e6-b10c-5e8440384e6b', 'Lime', '#00ff00', 5),
    ('45905a52-cac4-4219-a88c-84f1221a5824', 'Olive', '#808000', 6),
    ('0b500309-f056-4cad-a4ad-2e004c73a2ef', 'Yellow', '#ffff00', 7),
    ('d56a17f3-5ea9-4b8b-8956-cdbd5034c3ba', 'Navy', '#000080', 8),
    ('2e3e4de8-0300-42fe-8fb3-b421f2072bcc', 'Blue', '#0000ff', 9),
    ('9e14d1cc-8660-4da6-a356-cd909e94b78d', 'Teal', '#008080', 10),
    ('c17d0c69-f5f4-4dbd-ae14-f97e39dc113b', 'Aqua', '#00ffff', 11)
),
missing_cards AS (
  SELECT source_cards.*
  FROM source_cards
  WHERE NOT EXISTS (
    SELECT 1
    FROM cards
    WHERE subject_id = '0b84447d-3af3-4509-bdf6-c4e7fe822cc7'
      AND LOWER(TRIM(answer)) = LOWER(source_cards.color_name)
  )
),
existing_level AS (
  SELECT COALESCE(MAX(level), 0) AS base_level
  FROM cards
  WHERE subject_id = '0b84447d-3af3-4509-bdf6-c4e7fe822cc7'
),
numbered_cards AS (
  SELECT
    missing_cards.*,
    ROW_NUMBER() OVER (ORDER BY sort_order) AS level_offset
  FROM missing_cards
)
INSERT INTO cards (
  id,
  subject_id,
  owner_id,
  level,
  renderer,
  is_public,
  answer,
  answers,
  prompt,
  prompts,
  display_text,
  display_texts,
  images_base,
  images_local,
  audio,
  audios,
  video,
  videos,
  created_at,
  updated_at
)
SELECT
  numbered_cards.card_id,
  '0b84447d-3af3-4509-bdf6-c4e7fe822cc7',
  'usyeo7d2yzf2773',
  existing_level.base_level + numbered_cards.level_offset,
  'colors',
  1,
  numbered_cards.color_name,
  '{}',
  '',
  '{}',
  numbered_cards.hex_code,
  '{}',
  '[]',
  '{}',
  '',
  '{}',
  '',
  '{}',
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
FROM numbered_cards
CROSS JOIN existing_level;
