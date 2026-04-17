# Repository Guidelines

## Project Structure & Module Organization
Aliolo is a Flutter app with a Cloudflare Workers backend. Frontend code lives in `lib/`: shared infrastructure in `lib/core`, domain models and services in `lib/data`, and feature UI under `lib/features`. Backend code lives in `api/src`, with HTTP routes in `api/src/routes`, request/response schemas in `api/src/schemas`, and shared utilities in `api/src/utils`. Flutter unit and widget tests live in `test/`, Patrol and integration coverage live in `integration_test/`, and static media assets live in `assets/`.

## Build, Test, and Development Commands
Use the root scripts when possible:

- `./scripts/dev_backend.sh` runs `wrangler dev --remote` for the Worker API.
- `./scripts/dev_frontend.sh` starts Flutter web against `http://localhost:8787`.
- `./scripts/test_backend.sh` runs backend Vitest specs.
- `./scripts/test_frontend.sh` runs Flutter unit and widget tests.
- `./scripts/test_goldens.sh` runs widget goldens; add `--update` to refresh baselines.
- `./scripts/test_integration.sh` runs Patrol tests; requires a connected device/emulator.
- `./scripts/test_all.sh` runs the full test suite.
- `./scripts/build_frontend.sh` builds the production web app.
- `./scripts/deploy_backend.sh` deploys the Worker to production.

## Coding Style & Naming Conventions
Follow standard Flutter and TypeScript conventions. Use 2-space indentation in Dart and keep files `snake_case.dart`; classes, enums, and widgets use `PascalCase`; methods and variables use `camelCase`. Backend route and schema files are lowercase by domain, for example `api/src/routes/cards.ts` and `api/src/schemas/card.ts`. Prefer small services and focused route modules. Use `dart format .` and keep Dart code compatible with `flutter_lints`; keep TypeScript ESM-friendly and consistent with existing Hono route structure.

## Testing Guidelines
Add or update tests with every behavior change. Put Flutter unit tests in `test/unit`, widget tests in `test/widget`, and integration flows in `integration_test`. Name files with the `_test.dart` suffix. Backend tests run with Vitest from `api`; keep e2e coverage separate with `npm run test:e2e`. Refresh goldens intentionally and review diffs before committing.

## Commit & Pull Request Guidelines
Recent history uses Conventional Commit-style prefixes such as `feat:`, `fix:`, `refactor:`, and scoped forms like `fix(api):`. Keep subjects imperative and specific. PRs should include a short summary, affected areas (`lib/...`, `api/...`, scripts, schema), linked issues when applicable, and screenshots or recordings for UI changes. Note any required env vars, migrations, or production-impacting changes in the PR description.
