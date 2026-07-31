ALTER TABLE profiles ADD COLUMN learn_autoplay_delay_seconds INTEGER DEFAULT 3;
UPDATE profiles
SET learn_autoplay_delay_seconds = 3
WHERE learn_autoplay_delay_seconds IS NULL OR learn_autoplay_delay_seconds < 1;
