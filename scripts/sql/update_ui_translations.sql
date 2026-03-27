-- SQL Script to update UI translations for Documentation and Onboarding
-- You can run this in your Supabase SQL Editor

INSERT INTO ui_translations (lang, key, value)
VALUES 
  -- Documentation
  ('en', 'doc_welcome_title', 'Welcome to Aliolo'),
  ('en', 'doc_welcome_desc', 'Aliolo is a visual learning platform designed to help you master subjects through flashcards and interactive testing.'),
  ('en', 'doc_flashcards_title', 'Visual Flashcards'),
  ('en', 'doc_flashcards_desc', 'Each subject contains a set of cards with images and audio. You can browse through them to familiarize yourself with the content.'),
  ('en', 'doc_testing_title', 'Interactive Testing'),
  ('en', 'doc_testing_desc', 'Challenge yourself with multiple-choice questions (MCQ). The app will automatically advance as you answer, helping you learn faster.'),
  ('en', 'doc_streaks_title', 'Streak System'),
  ('en', 'doc_streaks_desc', 'Consistency is key! Complete your daily goal every day to build your streak. Don''t miss a day, or the streak will reset.'),
  ('en', 'doc_goals_title', 'Daily Goals'),
  ('en', 'doc_goals_desc', 'Set your daily card completion target in the settings. Changes to your goal take effect starting the next day.'),
  ('en', 'doc_sync_title', 'Cloud Sync'),
  ('en', 'doc_sync_desc', 'Your progress is automatically synced to the cloud. You can switch between web and desktop versions without losing your streak.'),
  
  -- Onboarding
  ('en', 'onboarding_1_title', 'Welcome to Aliolo'),
  ('en', 'onboarding_1_desc', 'Your personal visual learning assistant for mastering any subject.'),
  ('en', 'onboarding_2_title', 'Smart Learning'),
  ('en', 'onboarding_2_desc', 'Interactive flashcards with images and audio for faster memorization.'),
  ('en', 'onboarding_3_title', 'Track Progress'),
  ('en', 'onboarding_3_desc', 'Build your daily streak and watch your knowledge grow every day.'),
  ('en', 'onboarding_4_title', 'Connect & Share'),
  ('en', 'onboarding_4_desc', 'Learn together with friends and compete on the global leaderboard.'),
  ('en', 'onboarding_5_title', 'Cloud Sync'),
  ('en', 'onboarding_5_desc', 'Your data is always with you, synced across web and desktop apps.'),
  ('en', 'onboarding_6_title', 'Create Content'),
  ('en', 'onboarding_6_desc', 'Easily add your own subjects and share them with the community.'),
  ('en', 'onboarding_skip', 'Skip'),
  ('en', 'onboarding_next', 'Next'),
  ('en', 'onboarding_get_started', 'Get Started')
ON CONFLICT (lang, key) DO UPDATE SET value = EXCLUDED.value;
