# Google Play Verifier

Small Cloud Run service used by Aliolo to:

- verify Google Play subscriptions against Android Publisher
- receive Real-time Developer Notifications through Pub/Sub push
- trigger reconciliation runs against subscriptions already known by the Worker

## Required environment variables

- `GOOGLE_PLAY_PACKAGE_NAME`
- `WORKER_SHARED_SECRET`
- `WORKER_GOOGLE_PLAY_WEBHOOK_URL`
- `WORKER_GOOGLE_PLAY_RECONCILE_CANDIDATES_URL`

## Endpoints

- `POST /google-play/verify`
- `POST /google-play/rtdn`
- `POST /google-play/reconcile`

## Local build

```bash
cd google-play-verifier
npm install
npm run build
node dist/index.js
```
