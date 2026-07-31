# Aliolo Development Workflow

This document outlines the workflow for developing, testing, and deploying Aliolo.

## 🏗️ Environments

Aliolo uses a unified data approach for simplicity in this solo-developer phase.

- **Shared Resources**: Both Development and Production environments connect to the same Cloudflare D1 Database and R2 Buckets.
- **Isolation Strategy**: Use a dedicated "Test User" account for all development activities to avoid polluting production metrics (streaks, progress).

## ⚠️ Operational Constraints

- **Sandbox networking**: The local sandbox shell does not have outbound internet access. Network work that depends on external hosts must use an escalated command or run in the Cloudflare environment.
- **Card image storage convention**: Card media is stored in the `aliolo-media` bucket under `cards/<card_id>/global_<timestamp>.<ext>`.
- **Card image URL format**: `images_base` stores a JSON array of public URLs, typically like `["https://aliolo.com/storage/v1/object/public/aliolo-media/cards/<card_id>/global_<timestamp>.<ext>"]`.

---

## 💻 Local Development

### 1. Start the Backend
Run the backend locally but connected to the remote production database:
```bash
cd api
npx wrangler dev --remote
```
*The API will be available at `http://localhost:8787`.*

### 2. Run the Frontend
In VS Code, use the **Run and Debug** menu and select one of the following configurations:
- **Aliolo (Local API)**: Connects to your local `wrangler dev` server.
- **Aliolo Web (Chrome)**: Runs in browser pointing to the local API.

### 3. View API Documentation
When running locally, you can access the interactive Swagger UI at:
`http://localhost:8787/api/docs`

---

## 🧪 Testing

### Backend Tests
Run Vitest specs (includes D1 simulation):
```bash
cd api
npm test
```

### Frontend Tests
Run Flutter unit and widget tests:
```bash
flutter test
```

---

## 🚀 Production Deployment

### 1. Deploy the Backend
Deploy your changes to the production worker:
```bash
cd api
npx wrangler deploy --env production
```
*Note: This environment hides the `/api/docs` endpoint from the public.*

### 2. Build/Deploy the Frontend
Build the Flutter web app pointing to the production URL:
```bash
flutter build web --release --dart-define=API_URL=https://aliolo.com
```

---

## 🛠️ Configuration Details

- **Backend Config**: `api/wrangler.jsonc` defines the environments and bindings.
- **Flutter Network Config**: `lib/core/network/cloudflare_client.dart` reads the `API_URL` environment variable.
- **VS Code Config**: `.vscode/launch.json` contains the run arguments for different environments.

---

## 📜 Convenience Scripts

You can use these scripts from the project root:

- **Start Backend Dev**: `./scripts/dev_backend.sh`
- **Start Frontend Dev**: `./scripts/dev_frontend.sh`
- **Run All Tests**: `./scripts/test_all.sh`
- **Run E2E (Production) Tests**: `./scripts/test_e2e.sh`
- **Run Backend Tests**: `./scripts/test_backend.sh`
- **Run Frontend Tests**: `./scripts/test_frontend.sh`
- **Run Integration Tests**: `./scripts/test_integration.sh`
- **Run Golden Tests**: `./scripts/test_goldens.sh` (use `--update` to refresh baselines)
- **Build**: `./scripts/build.sh`
- **Deploy**: `./scripts/deploy.sh`
- **Generate UI Translations**: `python3 scripts/generate_ui_translations.py scan|sql|refresh`
