# Aliolo Project Context & Engineering Standards

This file serves as the primary context bridge for Gemini CLI. 

## 🏗️ Core Architecture
- **Framework:** Flutter (Mobile, Linux, Web)
- **Backend:** Cloudflare Stack (D1 Database, R2 Storage, Workers, Lucia Auth)
- **API Base:** `https://aliolo-backend.vitalii-e07.workers.dev`
- **Local State:** `ListenableBuilder` and `ValueListenableBuilder` used for UI reactivity.
- **Primary Features:** Visual flashcards, MCQ testing, Video/Audio support, Streak system, Age-based content filtering.

## 🔑 Key Feature Logic
- **Age Brackets:** Subjects are tagged with `age_group` (`early`, `primary`, `intermediate`, `advanced`). `advanced` is the default and is hidden from UI badges.
- **Daily Progress & Goals:** 
    - `daily_completions`: Tracks cards done today.
    - `daily_goal_count`: Current day's target.
    - `next_daily_goal`: Changes made to goal today only take effect tomorrow.
    - **Reset Logic:** Handled in `AuthService.init()` and `ProgressService`. Detects date change via `last_active_date`, resets `daily_completions` to 0 and updates `daily_goal_count` from `next_daily_goal`.
- **Streak System:** Increments only when `daily_completions` >= `daily_goal_count`.
- **Auto-play:** Testing sessions can advance automatically (1s for correct, 2s for wrong). Preference is saved in `auto_play_enabled`.
- **System Sounds:** Stored in `assets/media/` to support Web (`AssetSource`) and Linux (`DeviceFileSource`).

## 📁 Media Storage (Cloudflare R2)
- **Worker Proxy:** Media is served through `/storage/v1/object/public/:bucket/:path`
- **Buckets:** `aliolo-media` (cards, profiles).
- **Upload Restrictions:**
    - Profile Avatars: 1 MB
    - Card Images: 5 MB
    - Card Audio: 10 MB
    - Card Video: 50 MB

## 💾 Database Schema (Cloudflare D1)
- **Live Schema:** Relational SQLite-compatible schema in `scripts/sql/d1_schema.sql`.
- **`profiles` table:** Core user data, streak info, preferences.
- **`subjects` table:** `localized_data` (JSONB string).
- **`cards` table:** Belongs to subject, `localized_data` (JSONB string).
- **`progress` table:** Tracks user-card interactions.

## 🎨 UI & Layout Standards
- **Standard Top Offset:** 92.0px (used in `AlioloPage` and `AlioloScrollablePage`).
- **Control Spacing:** 
    - 8px between Search and Filters.
    - 24px-32px between Filters and Content List.
- **Editor Pattern:** "Save" and "Delete" buttons are pinned to the AppBar (Top Bar).
- **Filter Style:** `ChoiceChip` with `showCheckmark: false`.

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
- Continue refining the "Recent Subjects" row on the dashboard.
- Optimize D1 queries for faster synchronization.
- Implement real IAP verification in the Worker.
