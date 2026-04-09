# Aliolo Project Context & Engineering Standards

This file serves as the primary context bridge for Gemini CLI. 

## 🏗️ Core Architecture
- **Framework:** Flutter (Mobile, Linux, Web)
- **Backend:** Supabase (PostgreSQL, Auth, Storage)
- **Local State:** Currently relying on Supabase for sync; UI uses `ListenableBuilder` and `ValueListenableBuilder`.
- **Primary Features:** Visual flashcards, MCQ testing, Video/Audio support, Streak system, Age-based content filtering.

## 🔑 Key Feature Logic
- **Age Brackets:** Subjects are tagged with `age_group` (`early`, `primary`, `intermediate`, `advanced`). `advanced` is the default and is hidden from UI badges.
- **Daily Progress & Goals:** 
    - `daily_completions`: Tracks cards done today.
    - `daily_goal_count`: Current day's target.
    - `next_daily_goal`: Changes made to goal today only take effect tomorrow.
    - **Reset Logic:** Every morning (detected via `last_active_date`), `daily_completions` resets to 0 and `daily_goal_count` is updated from `next_daily_goal`.
- **Streak System:** Increments only when `daily_completions` >= `daily_goal_count`.
- **Auto-play:** Testing sessions can advance automatically (1s for correct, 2s for wrong). Preference is saved in `auto_play_enabled`.
- **System Sounds:** Stored in `assets/media/` to support Web (`AssetSource`) and Linux (`DeviceFileSource`).

## 📁 Media Upload Restrictions
- **Profile Avatars:** 1 MB
- **Card Images:** 5 MB
- **Card Audio:** 10 MB (Planned)
- **Card Video:** 50 MB (Planned)

## 💾 Database Schema (Supabase)
- **Live Schema:** The complete, live database schema is maintained in `DB_SCHEMA.md`. Always refer to it for the most accurate table and column definitions.
- **`profiles` table:**
    - `last_active_date` (TIMESTAMPTZ)
    - `daily_completions` (FLOAT)
    - `next_daily_goal` (INT)
    - `auto_play_enabled` (BOOL)
- **`subjects` table:**
    - `age_group` (TEXT)
    - `localized_data` (JSONB) - Replaces `names` and `descriptions`
- **`pillars` table:**
    - `sort_order` (INT)

## 🎨 UI & Layout Standards
- **Standard Top Offset:** 92.0px (used in `AlioloPage` and `AlioloScrollablePage`).
- **Control Spacing:** 
    - 8px between Search and Filters.
    - 24px-32px between Filters and Content List.
- **Editor Pattern:** "Save" and "Delete" buttons are pinned to the AppBar (Top Bar) for accessibility during scroll.
- **Filter Style:** `ChoiceChip` with `showCheckmark: false`, highlighted by the active theme color.

## 🛠️ Build Instructions
- **Web Build:** 
    ```bash
    flutter build web --release \
      --dart-define=SUPABASE_URL=$SUPABASE_URL \
      --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
    ```
- **Environment:** Linux (Primary dev environment).

## 🚀 Ongoing / Next Steps
- Continue refining the "Recent Subjects" row on the dashboard.
- Optimize Supabase queries for faster synchronization.
