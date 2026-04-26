# Aliolo Database Schema (Live Supabase)

Generated dynamically from the remote Supabase API.

### `folders`
- `id` (string) (Required): Note:
This is a Primary Key.<pk/>
- `pillar_id` (integer) (Required): Note:
This is a Foreign Key to `pillars.id`.<fk table='pillars' column='id'/>
- `owner_id` (string) (Required): Note:
This is a Foreign Key to `profiles.id`.<fk table='profiles' column='id'/>
- `name` (string) (Required)
- `names` (jsonb)
- `created_at` (string)
- `updated_at` (string)

### `collections`
- `id` (string) (Required): Note:
This is a Primary Key.<pk/>
- `pillar_id` (integer) (Required): Note:
This is a Foreign Key to `pillars.id`.<fk table='pillars' column='id'/>
- `folder_id` (string): Note:
This is a Foreign Key to `folders.id`.<fk table='folders' column='id'/>
- `owner_id` (string) (Required): Note:
This is a Foreign Key to `profiles.id`.<fk table='profiles' column='id'/>
- `name` (string) (Required)
- `names` (jsonb)
- `description` (string)
- `descriptions` (jsonb)
- `age_group` (string)
- `is_public` (boolean)
- `created_at` (string)
- `updated_at` (string)

### `feedback_replies`
- `id` (string) (Required): Note:
This is a Primary Key.<pk/>
- `created_at` (string)
- `feedback_id` (string): Note:
This is a Foreign Key to `feedbacks.id`.<fk table='feedbacks' column='id'/>
- `user_id` (string): Note:
This is a Foreign Key to `profiles.id`.<fk table='profiles' column='id'/>
- `content` (string) (Required)
- `attachment_urls` (array)

### `subjects`
- `id` (string) (Required): Note:
This is a Primary Key.<pk/>
- `pillar_id` (integer) (Required): Note:
This is a Foreign Key to `pillars.id`.<fk table='pillars' column='id'/>
- `owner_id` (string) (Required): Note:
This is a Foreign Key to `profiles.id`.<fk table='profiles' column='id'/>
- `is_public` (boolean)
- `updated_at` (string)
- `created_at` (string)
- `age_group` (string)
- `name` (string) (Required)
- `names` (jsonb)
- `description` (string)
- `descriptions` (jsonb)
- `folder_id` (string): Note:
This is a Foreign Key to `folders.id`.<fk table='folders' column='id'/>

### `user_subscriptions`
- `id` (string) (Required): Note:
This is a Primary Key.<pk/>
- `user_id` (string) (Required): Note:
This is a Foreign Key to `profiles.id`.<fk table='profiles' column='id'/>
- `status` (string) (Required)
- `provider` (string) (Required)
- `expiry_date` (string)
- `purchase_token` (string)
- `order_id` (string)
- `product_id` (string)
- `updated_at` (string)
- `created_at` (string)

### `profiles`
- `id` (string) (Required): Note:
This is a Primary Key.<pk/>
- `username` (string)
- `email` (string)
- `total_xp` (integer)
- `current_streak` (integer)
- `max_streak` (integer)
- `theme_mode` (string)
- `ui_language` (string)
- `daily_goal_count` (integer)
- `updated_at` (string)
- `sidebar_left` (boolean)
- `sound_enabled` (boolean)
- `show_on_leaderboard` (boolean)
- `learn_session_size` (integer)
- `options_count` (integer)
- `created_at` (string)
- `avatar_url` (string)
- `default_language` (string)
- `last_active_date` (string)
- `next_daily_goal` (integer)
- `daily_completions` (number)
- `auto_play_enabled` (boolean)
- `test_session_size` (integer)
- `main_pillar_id` (integer)
- `show_documentation` (boolean)

### `invitations`
- `id` (integer) (Required): Note:
This is a Primary Key.<pk/>
- `user_id` (string)
- `email` (string) (Required)
- `invited_by` (string)
- `created_at` (string)
- `inviter_id` (string)
- `invited_email` (string)

### `cards`
- `id` (string) (Required): Note:
This is a Primary Key.<pk/>
- `subject_id` (string) (Required): Note:
This is a Foreign Key to `subjects.id`.<fk table='subjects' column='id'/>
- `level` (integer)
- `owner_id` (string)
- `is_public` (boolean)
- `answer` (string)
- `answers` (jsonb)
- `prompt` (string)
- `prompts` (jsonb)
- `images_base` (jsonb)
- `images_local` (jsonb)
- `audio` (string)
- `audios` (jsonb)
- `video` (string)
- `videos` (jsonb)
- `created_at` (string)
- `updated_at` (string)
- `test_mode` (string)

### `languages`
- `id` (string) (Required): Note:
This is a Primary Key.<pk/>
- `name` (string) (Required)

UI chrome translation strings are stored in the backend only:
- `languages` defines the available UI locales.
- `ui_translations` stores the actual key/value strings for each locale.

Card and subject content localization is separate and lives on the content models themselves (`prompts`, `answers`, `display_texts`, localized media, etc.).

### `user_subjects`
- `id` (integer) (Required): Note:
This is a Primary Key.<pk/>
- `user_id` (string) (Required): Note:
This is a Foreign Key to `profiles.id`.<fk table='profiles' column='id'/>
- `subject_id` (string)
- `created_at` (string)
- `collection_id` (string): Note:
This is a Foreign Key to `collections.id`.<fk table='collections' column='id'/>

### `collection_items`
- `id` (string) (Required): Note:
This is a Primary Key.<pk/>
- `collection_id` (string) (Required): Note:
This is a Foreign Key to `collections.id`.<fk table='collections' column='id'/>
- `subject_id` (string) (Required): Note:
This is a Foreign Key to `subjects.id`.<fk table='subjects' column='id'/>
- `created_at` (string)

### `feedbacks`
- `id` (string) (Required): Note:
This is a Primary Key.<pk/>
- `created_at` (string)
- `user_id` (string): Note:
This is a Foreign Key to `profiles.id`.<fk table='profiles' column='id'/>
- `type` (string) (Required)
- `title` (string) (Required)
- `content` (string) (Required)
- `attachment_urls` (array)
- `status` (string)
- `metadata` (jsonb)

### `ui_translations`
- `key` (string) (Required): Note:
This is a Primary Key.<pk/>
- `lang` (string) (Required): Note:
This is a Primary Key.<pk/>
- `value` (string) (Required)
- `updated_at` (string) (Required)

### `user_friendships`
- `id` (integer) (Required): Note:
This is a Primary Key.<pk/>
- `sender_id` (string) (Required): Note:
This is a Foreign Key to `profiles.id`.<fk table='profiles' column='id'/>
- `receiver_id` (string) (Required): Note:
This is a Foreign Key to `profiles.id`.<fk table='profiles' column='id'/>
- `status` (string) (Required)
- `created_at` (string)

### `progress`
Stores per-user card test progress and SM-2 spaced repetition state. Learn mode
does not advance these fields; Test mode updates review scheduling after each
answer.

- `id` (integer) (Required): Note:
This is a Primary Key.<pk/>
- `user_id` (string) (Required): Note:
This is a Foreign Key to `profiles.id`.<fk table='profiles' column='id'/>
- `card_id` (string): Note:
This is a Foreign Key to `cards.id`.<fk table='cards' column='id'/>
- `subject_id` (string): Note:
This is a Foreign Key to `subjects.id`.<fk table='subjects' column='id'/>
- `correct_count` (integer)
- `ease_factor` (number)
- `interval` (integer)
- `repetition_count` (integer)
- `next_review` (string)
- `updated_at` (string)
- `is_hidden` (boolean)
- `created_at` (string)

### `subject_usage_stats`
Individual subject study sessions recording.

- `id` (integer) (Primary Key)
- `subject_id` (string) (Required): Foreign Key to `subjects.id`
- `user_id` (string) (Required): Current user ID
- `mode` (string) (Required): `learn` or `test`
- `completed` (boolean): Whether the session was finished
- `created_at` (string)

### `pillars`
- `id` (integer) (Required): Note:
This is a Primary Key.<pk/>
- `light_color` (string)
- `dark_color` (string)
- `icon` (string)
- `sort_order` (integer)
- `name` (string) (Required)
- `names` (jsonb)
- `description` (string)
- `descriptions` (jsonb)

### `onboarding_analytics`
- `id` (string) (Required): Note:
This is a Primary Key.<pk/>
- `session_id` (string) (Required)
- `age_range` (string)
- `pillar_id` (integer)
- `created_at` (string)
- `last_slide_index` (integer)
