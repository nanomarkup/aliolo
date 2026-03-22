-- RLS for collections
ALTER TABLE collections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public collections view" ON collections;
CREATE POLICY "Public collections view"
ON collections FOR SELECT
USING ( is_public = true OR auth.uid()::text = owner_id );

DROP POLICY IF EXISTS "Users can insert their own collections" ON collections;
CREATE POLICY "Users can insert their own collections"
ON collections FOR INSERT
WITH CHECK ( auth.uid()::text = owner_id );

DROP POLICY IF EXISTS "Users can update their own collections" ON collections;
CREATE POLICY "Users can update their own collections"
ON collections FOR UPDATE
USING ( auth.uid()::text = owner_id );

DROP POLICY IF EXISTS "Users can delete their own collections" ON collections;
CREATE POLICY "Users can delete their own collections"
ON collections FOR DELETE
USING ( auth.uid()::text = owner_id );

-- RLS for collection_items
ALTER TABLE collection_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Collection items view" ON collection_items;
CREATE POLICY "Collection items view"
ON collection_items FOR SELECT
USING ( 
  EXISTS (
    SELECT 1 FROM collections 
    WHERE collections.id = collection_id 
    AND (collections.is_public = true OR collections.owner_id = auth.uid()::text)
  )
);

DROP POLICY IF EXISTS "Users can manage their own collection items" ON collection_items;
CREATE POLICY "Users can manage their own collection items"
ON collection_items FOR ALL
USING ( 
  EXISTS (
    SELECT 1 FROM collections 
    WHERE collections.id = collection_id 
    AND collections.owner_id = auth.uid()::text
  )
);
