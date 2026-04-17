ALTER TABLE cards ADD COLUMN display_text TEXT NOT NULL DEFAULT '';
ALTER TABLE cards ADD COLUMN display_texts TEXT NOT NULL DEFAULT '{}';

UPDATE cards
SET display_text = prompt
WHERE renderer = 'math' AND (display_text IS NULL OR display_text = '');
