# Aliolo Project Context & Engineering Standards

This file serves as the primary context bridge for Gemini CLI. 

## 🏗️ Core Architecture
- **Framework:** Flutter (Mobile, Linux, Web)
- **Backend:** Cloudflare Stack (D1 Database, R2 Storage, Workers, Lucia Auth)
- **API Base:** `https://aliolo.com` (Production), `http://localhost:8787` (Local)
- **Local State:** `ListenableBuilder` and `ValueListenableBuilder` used for UI reactivity.
- **Primary Features:** Visual flashcards, MCQ testing, Video/Audio support, Streak system, Age-based content filtering.

## 🔑 Key Feature Logic
- **Age Brackets:** Subjects and collections use `age_group` (`0_6`, `7_14`, `15_plus`). `15_plus` is the default.
- **Daily Progress & Goals:** 
    - `daily_completions`: Tracks cards done today.
    - `daily_goal_count`: Current day's target.
    - `next_daily_goal`: Changes made to goal today only take effect tomorrow.
    - **Reset Logic:** Handled in `AuthService.init()`. Detects date change via `last_active_date`, resets `daily_completions` to 0 and updates `daily_goal_count` from `next_daily_goal`.
- **Streak System:** Increments only when `daily_completions` >= `daily_goal_count`.
- **Auto-play:** Testing sessions can advance automatically (1s for correct, 2s for wrong). Preference is saved in `auto_play_enabled`.
- **System Sounds:** Stored in `assets/media/` to support Web (`AssetSource`) and Linux (`DeviceFileSource`).

## 📁 Media Storage (Cloudflare R2)
- **Bucket:** `aliolo-media` (Main storage for all media).
- **Worker Proxy:** Media is served through `/storage/v1/object/public/:bucket/:path`
- **Card Media Organization:**
    - All media files for a card are stored in a dedicated folder named after the `card_id`: `cards/{card_id}/`.
    - There are no separate subfolders for images/audio/video within the card's folder; everything is flat.
- **File Naming Convention:**
    - Pattern: `[localization_prefix]_[datetimestamp].[original_extension]`
    - Example: `en_1712880000000.jpg`, `es_1712880001000.mp4`.
    - This convention is critical for tracking localizations and preventing collisions.
- **Upload Restrictions:**
    - Profile Avatars: 1 MB
    - Card Images: 5 MB
    - Card Audio: 10 MB
    - Card Video: 50 MB

## 💾 Database Schema (Cloudflare D1)
- **`profiles` table:** Core user data, streak info, preferences.
    - Fields: `id`, `username`, `email`, `total_xp`, `current_streak`, `max_streak`, `daily_goal_count`, `daily_completions`, `auto_play_enabled`, `test_session_size`, `learn_session_size`, `main_pillar_id`, `show_documentation`, `avatar_url`, `theme_mode`, `ui_language`, `sidebar_left`, `sound_enabled`, `show_on_leaderboard`, `default_language`, `last_active_date`, `next_daily_goal`, `is_premium`.
- **`subjects` table:** Content groups.
    - Fields: `id`, `pillar_id`, `folder_id`, `owner_id`, `is_public`, `age_group`, `name`, `names` (JSON), `description`, `descriptions` (JSON).
- **`cards` table:** Individual flashcards.
    - Fields: `id`, `subject_id`, `level`, `owner_id`, `is_public`, `answer`, `answers` (JSON), `prompt`, `prompts` (JSON), `images_base` (JSON), `images_local` (JSON), `audio`, `audios` (JSON), `video`, `videos` (JSON), `test_mode`.
- **`progress` table:** Tracks user-card interactions (SRS logic).

## 🎨 UI & Layout Standards
- **Standard Top Offset:** 92.0px (used in `AlioloPage` and `AlioloScrollablePage`).
- **Control Spacing:** 
    - 8px between Search and Filters.
    - 24px-32px between Filters and Content List.
- **Editor Pattern:** "Save" and "Delete" buttons are pinned to the AppBar (Top Bar).
- **Filter Style:** `_buildCompactDropdown` with custom styling (replaces legacy `ChoiceChip`).

## 🛠️ Build & Deploy
- **Detailed Workflow**: See `DEVELOPMENT.md` for local setup and production deployment instructions.
- **Backend (Worker):**
    ```bash
    cd api
    npx wrangler deploy --env production
    ```
- **Web Build:** 
    ```bash
    flutter build web --release --dart-define=API_URL=https://aliolo.com
    ```
- **Environment:** Linux (Primary dev environment).

## 🧪 Testing & AI Rules
- **Strict Linting**: The codebase enforces strict Dart rules in `analysis_options.yaml` and strict TypeScript in `api/tsconfig.json`. Ensure all generated code adheres to strong typing, prefers `const` constructors, and avoids `dynamic` types.
- **Golden Tests**: For any core UI component modification, a Golden Test (`golden_toolkit`) must be written or updated in `test/widget/` to prevent visual regressions. To update goldens, run `flutter test --update-goldens`.
- **E2E Tests**: Core user flows should be tested using the `patrol` package in `integration_test/`. Patrol provides a highly readable, English-like syntax for navigation and assertion.

## 🚀 Ongoing / Next Steps
- Implement real IAP verification in the Worker.
- Optimize D1 queries for faster synchronization.
- Expand "Library" with more curated subjects.
