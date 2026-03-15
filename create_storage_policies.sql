-- Run this in your Supabase SQL Editor to set up policies for the new buckets

-- 1. Policies for card_audio
CREATE POLICY "Public Audio View"
ON storage.objects FOR SELECT
USING ( bucket_id = 'card_audio' );

CREATE POLICY "Authenticated Users can upload audio"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'card_audio' 
    AND auth.role() = 'authenticated'
);

CREATE POLICY "Users can update their own audio"
ON storage.objects FOR UPDATE
USING (
    bucket_id = 'card_audio' 
    AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can delete their own audio"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'card_audio' 
    AND auth.uid()::text = (storage.foldername(name))[1]
);

-- 2. Policies for card_videos
CREATE POLICY "Public Video View"
ON storage.objects FOR SELECT
USING ( bucket_id = 'card_videos' );

CREATE POLICY "Authenticated Users can upload videos"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'card_videos' 
    AND auth.role() = 'authenticated'
);

CREATE POLICY "Users can update their own videos"
ON storage.objects FOR UPDATE
USING (
    bucket_id = 'card_videos' 
    AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can delete their own videos"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'card_videos' 
    AND auth.uid()::text = (storage.foldername(name))[1]
);
