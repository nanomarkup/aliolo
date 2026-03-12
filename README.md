# Aliolo - Your Logic Ally

Aliolo is a visual learning platform designed to help users master various subjects through interactive flashcards, multi-image prompts, and video content. It features a robust categorization system (Pillars), cloud synchronization via Supabase, and a competitive leaderboard.

## Key Features

- **Pillar-Based Learning**: Subjects are organized into high-level categories (Pillars) for structured learning.
- **Multilingual Support**: Learn in multiple languages with dynamic UI translation and content filtering.
- **Interactive Flashcards**: Support for multiple-choice questions (MCQ), multiple images per card, and video playback.
- **Manage Subjects**: Create, edit, and share your own subjects and cards.
- **Cloud Sync**: Seamlessly sync progress and content across devices using Supabase.
- **Competitive Leaderboard**: Compete globally or with friends based on total XP.
- **Cross-Platform**: Built with Flutter for Linux, Web, and other supported platforms.

## Tech Stack

- **Framework**: [Flutter](https://flutter.dev/)
- **Backend**: [Supabase](https://supabase.com/) (Auth, Database, Storage)
- **Local Cache**: [Isar](https://isar.dev/)
- **Media**: [media_kit](https://pub.dev/packages/media_kit) for high-performance video playback.

## Development

### Prerequisites

- Flutter SDK
- Supabase Project

### Building

#### Linux
```bash
flutter build linux --release
```

#### Web
```bash
python3 fix_web_build_v2.py
cd aliolo
flutter build web --release
```

## Directory Structure

- `lib/core`: Dependency injection, widgets, and utilities.
- `lib/data`: Models and services (Supabase, Progress, Sound, etc.).
- `lib/features`: UI features (Auth, Learning, Leaderboard, Management).
- `assets/lang`: UI translation files.
