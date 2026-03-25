ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Public profiles are viewable by everyone" ON public.profiles FOR SELECT USING ( true );
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING ( auth.uid()::text = id::text );

ALTER TABLE public.folders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all users to view folders" ON public.folders;
CREATE POLICY "Allow all users to view folders" ON public.folders FOR SELECT USING ( true );
DROP POLICY IF EXISTS "Users can insert folders" ON public.folders;
CREATE POLICY "Users can insert folders" ON public.folders FOR INSERT WITH CHECK ( auth.uid()::text = owner_id::text );
DROP POLICY IF EXISTS "Users can update their own folders" ON public.folders;
CREATE POLICY "Users can update their own folders" ON public.folders FOR UPDATE USING ( auth.uid()::text = owner_id::text );
DROP POLICY IF EXISTS "Users can delete their own folders" ON public.folders;
CREATE POLICY "Users can delete their own folders" ON public.folders FOR DELETE USING ( auth.uid()::text = owner_id::text );

ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public subjects view" ON public.subjects;
CREATE POLICY "Public subjects view" ON public.subjects FOR SELECT USING ( is_public = true OR auth.uid()::text = owner_id::text );
DROP POLICY IF EXISTS "Users can insert subjects" ON public.subjects;
CREATE POLICY "Users can insert subjects" ON public.subjects FOR INSERT WITH CHECK ( auth.uid()::text = owner_id::text );
DROP POLICY IF EXISTS "Users can update own subjects" ON public.subjects;
CREATE POLICY "Users can update own subjects" ON public.subjects FOR UPDATE USING ( auth.uid()::text = owner_id::text );
DROP POLICY IF EXISTS "Users can delete own subjects" ON public.subjects;
CREATE POLICY "Users can delete own subjects" ON public.subjects FOR DELETE USING ( auth.uid()::text = owner_id::text );

ALTER TABLE public.cards ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Cards viewable via subject" ON public.cards;
CREATE POLICY "Cards viewable via subject" ON public.cards FOR SELECT USING ( EXISTS ( SELECT 1 FROM subjects WHERE subjects.id::text = subject_id::text AND (subjects.is_public = true OR subjects.owner_id::text = auth.uid()::text) ) );
DROP POLICY IF EXISTS "Users can manage cards of their own subjects" ON public.cards;
CREATE POLICY "Users can manage cards of their own subjects" ON public.cards FOR ALL USING ( EXISTS ( SELECT 1 FROM subjects WHERE subjects.id::text = subject_id::text AND subjects.owner_id::text = auth.uid()::text ) );

ALTER TABLE public.collections ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public collections view" ON public.collections;
CREATE POLICY "Public collections view" ON public.collections FOR SELECT USING ( is_public = true OR auth.uid()::text = owner_id::text );
DROP POLICY IF EXISTS "Users can manage own collections" ON public.collections;
CREATE POLICY "Users can manage own collections" ON public.collections FOR ALL USING ( auth.uid()::text = owner_id::text );

ALTER TABLE public.collection_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Collection items view" ON public.collection_items;
CREATE POLICY "Collection items view" ON public.collection_items FOR SELECT USING ( EXISTS ( SELECT 1 FROM collections WHERE collections.id::text = collection_id::text AND (collections.is_public = true OR collections.owner_id::text = auth.uid()::text) ) );
DROP POLICY IF EXISTS "Users can manage own collection items" ON public.collection_items;
CREATE POLICY "Users can manage own collection items" ON public.collection_items FOR ALL USING ( EXISTS ( SELECT 1 FROM collections WHERE collections.id::text = collection_id::text AND collections.owner_id::text = auth.uid()::text ) );

ALTER TABLE public.feedbacks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can insert feedback" ON public.feedbacks;
CREATE POLICY "Users can insert feedback" ON public.feedbacks FOR INSERT WITH CHECK ( auth.role() = 'authenticated' );
DROP POLICY IF EXISTS "Users can view own feedback" ON public.feedbacks;
CREATE POLICY "Users can view own feedback" ON public.feedbacks FOR SELECT USING ( auth.uid()::text = user_id::text );

ALTER TABLE public.feedback_replies ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view relevant feedback replies" ON public.feedback_replies;
CREATE POLICY "Users can view relevant feedback replies" ON public.feedback_replies FOR SELECT USING ( auth.uid()::text = user_id::text OR EXISTS ( SELECT 1 FROM feedbacks WHERE feedbacks.id::text = feedback_id::text AND feedbacks.user_id::text = auth.uid()::text ) );
DROP POLICY IF EXISTS "Users can insert feedback replies" ON public.feedback_replies;
CREATE POLICY "Users can insert feedback replies" ON public.feedback_replies FOR INSERT WITH CHECK ( auth.role() = 'authenticated' );

ALTER TABLE public.user_subjects ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own dashboard" ON public.user_subjects;
CREATE POLICY "Users can manage their own dashboard" ON public.user_subjects FOR ALL USING ( auth.uid()::text = user_id::text );

ALTER TABLE public.progress ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage their own progress" ON public.progress;
CREATE POLICY "Users can manage their own progress" ON public.progress FOR ALL USING ( auth.uid()::text = user_id::text );

ALTER TABLE public.user_friendships ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own friendships" ON public.user_friendships;
CREATE POLICY "Users can view own friendships" ON public.user_friendships FOR SELECT USING ( auth.uid()::text = sender_id::text OR auth.uid()::text = receiver_id::text );
DROP POLICY IF EXISTS "Users can send friendship requests" ON public.user_friendships;
CREATE POLICY "Users can send friendship requests" ON public.user_friendships FOR INSERT WITH CHECK ( auth.uid()::text = sender_id::text );
DROP POLICY IF EXISTS "Users can respond to friendship requests" ON public.user_friendships;
CREATE POLICY "Users can respond to friendship requests" ON public.user_friendships FOR UPDATE USING ( auth.uid()::text = receiver_id::text );
DROP POLICY IF EXISTS "Users can delete own friendships" ON public.user_friendships;
CREATE POLICY "Users can delete own friendships" ON public.user_friendships FOR DELETE USING ( auth.uid()::text = sender_id::text OR auth.uid()::text = receiver_id::text );

ALTER TABLE public.pillars ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Pillars are viewable by everyone" ON public.pillars;
CREATE POLICY "Pillars are viewable by everyone" ON public.pillars FOR SELECT USING ( true );

ALTER TABLE public.languages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Languages are viewable by everyone" ON public.languages;
CREATE POLICY "Languages are viewable by everyone" ON public.languages FOR SELECT USING ( true );

ALTER TABLE public.ui_translations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "UI translations are viewable by everyone" ON public.ui_translations;
CREATE POLICY "UI translations are viewable by everyone" ON public.ui_translations FOR SELECT USING ( true );

DROP POLICY IF EXISTS "Public Audio View" ON storage.objects;
CREATE POLICY "Public Audio View" ON storage.objects FOR SELECT USING ( bucket_id = 'card_audio' );
DROP POLICY IF EXISTS "Secure audio upload" ON storage.objects;
CREATE POLICY "Secure audio upload" ON storage.objects FOR INSERT WITH CHECK ( bucket_id = 'card_audio' AND auth.role() = 'authenticated' AND (storage.foldername(name))[1] = auth.uid()::text );
DROP POLICY IF EXISTS "Users can manage their own audio" ON storage.objects;
CREATE POLICY "Users can manage their own audio" ON storage.objects FOR ALL USING ( bucket_id = 'card_audio' AND auth.uid()::text = (storage.foldername(name))[1] );

DROP POLICY IF EXISTS "Public Video View" ON storage.objects;
CREATE POLICY "Public Video View" ON storage.objects FOR SELECT USING ( bucket_id = 'card_videos' );
DROP POLICY IF EXISTS "Secure video upload" ON storage.objects;
CREATE POLICY "Secure video upload" ON storage.objects FOR INSERT WITH CHECK ( bucket_id = 'card_videos' AND auth.role() = 'authenticated' AND (storage.foldername(name))[1] = auth.uid()::text );
DROP POLICY IF EXISTS "Users can manage their own videos" ON storage.objects;
CREATE POLICY "Users can manage their own videos" ON storage.objects FOR ALL USING ( bucket_id = 'card_videos' AND auth.uid()::text = (storage.foldername(name))[1] );

DROP POLICY IF EXISTS "Public Image View" ON storage.objects;
CREATE POLICY "Public Image View" ON storage.objects FOR SELECT USING ( bucket_id = 'card_images' );
DROP POLICY IF EXISTS "Secure image upload" ON storage.objects;
CREATE POLICY "Secure image upload" ON storage.objects FOR INSERT WITH CHECK ( bucket_id = 'card_images' AND auth.role() = 'authenticated' AND (storage.foldername(name))[1] = auth.uid()::text );
DROP POLICY IF EXISTS "Users can manage their own images" ON storage.objects;
CREATE POLICY "Users can manage their own images" ON storage.objects FOR ALL USING ( bucket_id = 'card_images' AND auth.uid()::text = (storage.foldername(name))[1] );

DROP POLICY IF EXISTS "Avatars View" ON storage.objects;
CREATE POLICY "Avatars View" ON storage.objects FOR SELECT USING ( bucket_id = 'avatars' );
DROP POLICY IF EXISTS "Secure avatar upload" ON storage.objects;
CREATE POLICY "Secure avatar upload" ON storage.objects FOR INSERT WITH CHECK ( bucket_id = 'avatars' AND auth.role() = 'authenticated' AND (storage.foldername(name))[1] = auth.uid()::text );
DROP POLICY IF EXISTS "Users can manage their own avatars" ON storage.objects;
CREATE POLICY "Users can manage their own avatars" ON storage.objects FOR ALL USING ( bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1] );

DROP POLICY IF EXISTS "Feedback Attachments View" ON storage.objects;
CREATE POLICY "Feedback Attachments View" ON storage.objects FOR SELECT USING ( bucket_id = 'feedback_attachments' );
DROP POLICY IF EXISTS "Secure feedback attachment upload" ON storage.objects;
CREATE POLICY "Secure feedback attachment upload" ON storage.objects FOR INSERT WITH CHECK ( bucket_id = 'feedback_attachments' AND auth.role() = 'authenticated' AND (storage.foldername(name))[1] = auth.uid()::text );
DROP POLICY IF EXISTS "Users can manage their own feedback attachments" ON storage.objects;
CREATE POLICY "Users can manage their own feedback attachments" ON storage.objects FOR ALL USING ( bucket_id = 'feedback_attachments' AND auth.uid()::text = (storage.foldername(name))[1] );
