-- Drop the unnecessary contextual columns from the feedbacks table
-- since we are now storing this information flexibly within the metadata JSONB column.

ALTER TABLE feedbacks
DROP COLUMN IF EXISTS subject_id,
DROP COLUMN IF EXISTS card_id;
