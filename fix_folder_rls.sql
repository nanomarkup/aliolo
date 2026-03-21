-- Ensure folders are visible to all users so that public subjects within them
-- can be navigated to via their parent folder.

DROP POLICY IF EXISTS "Public folder view" ON folders;
DROP POLICY IF EXISTS "Users can view their own folders" ON folders;

CREATE POLICY "Allow all users to view folders"
ON folders FOR SELECT
USING ( true );

-- Ensure users can only modify their own folders
DROP POLICY IF EXISTS "Users can update their own folders" ON folders;
CREATE POLICY "Users can update their own folders"
ON folders FOR UPDATE
USING ( auth.uid()::text = owner_id );

DROP POLICY IF EXISTS "Users can delete their own folders" ON folders;
CREATE POLICY "Users can delete their own folders"
ON folders FOR DELETE
USING ( auth.uid()::text = owner_id );

DROP POLICY IF EXISTS "Users can insert folders" ON folders;
CREATE POLICY "Users can insert folders"
ON folders FOR INSERT
WITH CHECK ( auth.uid()::text = owner_id );
