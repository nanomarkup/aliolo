-- This script clears the description field from the localized_data JSONB in the folders table.
-- Folders should only have a 'name' in their localized_data.

UPDATE folders
SET localized_data = (
  SELECT jsonb_object_agg(lang, jsonb_build_object('name', data->>'name'))
  FROM jsonb_each(localized_data) AS x(lang, data)
  WHERE data ? 'name'
)
WHERE localized_data IS NOT NULL;
