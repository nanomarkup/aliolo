# Aliolo Development and Deployment

Aliolo intentionally uses two environments: isolated local development and Cloudflare production. There is no staging environment.

## Deployment model

- GitHub is the source of truth for code, CI results, and build artifacts.
- Local machines are used for development and preflight testing.
- Cloudflare Workers serves the API and Flutter web assets.
- Cloudflare D1 and R2 hold production data and media.
- A push to `main` deploys automatically only after backend tests, Flutter tests, static analysis, and a production web build succeed.
- Pull requests run the same checks but never deploy.

The deployment workflow is `.github/workflows/ci.yml`. It builds the web artifact once, stores it in GitHub Actions, and deploys that tested artifact with the Worker code from the same commit.

## One-time GitHub setup

Add these GitHub repository or `production` environment secrets:

- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_API_TOKEN`

The API token should be limited to the Aliolo Cloudflare account and only the permissions required to deploy the Worker and its bindings.

The workflow uses a GitHub environment named `production` for deployment history. It does not require an approval rule because this project deploys automatically after tests pass.

## Local development

Install Flutter, Node.js, and the backend dependencies:

```bash
flutter pub get
cd api
npm ci
cd ..
```

Start the backend:

```bash
./scripts/dev_backend.sh
```

This initializes a local-only D1 schema and starts Wrangler at `http://localhost:8787`. Wrangler also uses local R2 storage. The command does not access production D1 or R2.

In another terminal, start Flutter web:

```bash
./scripts/dev_frontend.sh
```

Local API documentation is available at `http://localhost:8787/api/docs`.

### Local email and OTP codes

When SMTP settings are absent in local development, emails and OTP codes are written to the backend console. To send real local emails, copy `api/.dev.vars.example` to `api/.dev.vars` and fill in the values. `.dev.vars` is ignored by Git.

## Testing locally

Run the checks that gate production:

```bash
./scripts/test_ci.sh
```

This runs:

1. Flutter static analysis. Existing warnings are reported but do not fail deployment yet.
2. Flutter unit and widget tests, excluding visual golden snapshots.
3. Isolated backend Vitest tests using a simulated D1 database.

Optional suites are kept separate:

```bash
./scripts/test_goldens.sh       # Visual snapshots; review image changes
./scripts/test_integration.sh   # Patrol; requires a device or emulator
./scripts/test_e2e.sh           # Explicit checks against production
./scripts/test_all.sh           # Every suite above
```

Production E2E tests are not part of normal local or pull-request checks because they access live services.

## Normal production release

The recommended flow is:

1. Make and test changes locally.
2. Push a feature branch and optionally open a pull request.
3. Confirm the GitHub checks pass.
4. Merge to `main`, or push directly to `main` for a small trusted change.
5. GitHub rebuilds and retests the exact `main` commit.
6. If every required job passes, GitHub deploys the Worker and tested web artifact to Cloudflare.
7. The workflow smoke-tests the homepage, pillars endpoint, and languages endpoint.

If a test or build fails, the production deployment job is skipped and the currently deployed version remains live.

## Manual GitHub run

The `CI and Production Deploy` workflow can be started from the GitHub Actions page. Select `main` and leave `deploy_production` enabled. Tests and the web build still run before deployment.

## Emergency local deployment

GitHub Actions is the normal deployment path. If GitHub is unavailable and an urgent production fix is required:

```bash
./scripts/deploy.sh --confirm-production
```

The fallback runs the production-gating tests, builds Flutter web, deploys with Wrangler, and runs the production smoke checks. It requires an authenticated Wrangler session.

## Rollback

Worker code and web assets can be rolled back from Cloudflare Workers & Pages → Aliolo → Deployments, or with `wrangler rollback`.

D1 and R2 data are not rolled back with Worker code. Database changes must therefore remain backward-compatible with the previous application version.

## Platform releases

`.github/workflows/build_apps.yml` remains a manual workflow for Android, iOS, Linux, macOS, and Windows artifacts. Android upload to the Google Play internal track remains opt-in. Platform builds do not control web production deployment.

## Production data safety

Commands containing `--remote` can change production resources. They must remain explicit maintenance operations and must not be added to normal local development or CI tests.

Card media in production is stored in the `aliolo-media` R2 bucket under `cards/<card_id>/...`. Public URLs are served through `https://aliolo.com/storage/v1/object/public/aliolo-media/...`.
