# Aliolo - Your Logic Ally

Aliolo is a visual learning platform designed to help users master various subjects through interactive flashcards, multi-image prompts, and video content. It features a robust categorization system (Pillars), cloud synchronization, and a competitive leaderboard.

## Key Features

- **Pillar-Based Learning**: Subjects are organized into high-level categories (Pillars) for structured learning.
- **Multilingual Support**: Learn in multiple languages with dynamic UI translation and content filtering.
- **Interactive Flashcards**: Support for multiple-choice questions (MCQ), multiple images per card, and video/audio playback.
- **Manage Subjects**: Create, edit, and share your own subjects, collections, and cards.
- **Age-Based Content Filtering**: Tailored learning paths for different age brackets (`0-6`, `7-14`, `15+`).
- **Cloud Sync**: Seamlessly sync progress and content across devices.
- **Competitive Leaderboard**: Compete globally based on total XP and streaks.
- **Cross-Platform**: Built with Flutter for Linux, Web, and Mobile.

## Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) (Mobile, Linux, Web)
- **Backend**: [Cloudflare Stack](https://workers.cloudflare.com/) (Workers, D1 Database, R2 Storage)
- **Authentication**: [Lucia Auth](https://lucia-auth.com/)
- **API**: [Hono](https://hono.dev/) with Zod-OpenAPI for type-safe routes.
- **Media**: [media_kit](https://pub.dev/packages/media_kit) for high-performance video/audio playback.

## Development

### Prerequisites

- Flutter SDK
- Node.js & npm (for backend development)
- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/install-and-update/)

### Building

#### Backend (Cloudflare Worker)
```bash
cd api
npx wrangler dev --remote # Local development
npx wrangler deploy --env production # Deployment
```

#### Frontend (Flutter)
```bash
# Linux
flutter build linux --release

# Web
flutter build web --release --dart-define=API_URL=https://aliolo.com
```

## Directory Structure

- `lib/core`: Dependency injection, shared widgets, and utilities.
- `lib/data`: Models and services (Auth, Progress, Card service, etc.).
- `lib/features`: UI features (Auth, Testing, Leaderboard, Management, Subjects).
- `api/src`: Backend implementation (Hono routes, Zod schemas, Auth logic).
- `scripts/`: Convenience scripts for testing and deployment.

## Documentation

For more detailed engineering standards and project context, refer to `GEMINI.md` and `DEVELOPMENT.md`.
