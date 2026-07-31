# Google Play Verifier Cloud Run Deploy

## Required Google Cloud setup

- Enable:
  - Cloud Run Admin API
  - Cloud Build API
  - Artifact Registry or Container Registry support used by `gcloud builds submit`
  - Android Publisher API
- Create a dedicated service account for Cloud Run.
- Grant that service account Android Publisher access in Play Console for `com.nanomarkup.aliolo`.

## Required local environment variables

```bash
export GCP_PROJECT_ID="your-gcp-project-id"
export GCP_REGION="europe-west1"
export GOOGLE_PLAY_VERIFIER_SERVICE="aliolo-google-play-verifier"
export GOOGLE_PLAY_PACKAGE_NAME="com.nanomarkup.aliolo"
export WORKER_SHARED_SECRET="replace-with-a-long-random-secret"
export WORKER_GOOGLE_PLAY_WEBHOOK_URL="https://aliolo.com/api/subscriptions/google/webhook"
export WORKER_GOOGLE_PLAY_RECONCILE_CANDIDATES_URL="https://aliolo.com/api/subscriptions/google/reconcile-candidates"
export GOOGLE_PLAY_VERIFIER_SERVICE_ACCOUNT="aliolo-google-play-verifier@your-gcp-project-id.iam.gserviceaccount.com"
```

## Deploy

```bash
./scripts/deploy_google_play_verifier.sh
```

## After deploy

1. Get the Cloud Run service URL.
2. Set Worker env vars:
   - `GOOGLE_PLAY_VERIFIER_URL`
   - `GOOGLE_PLAY_VERIFIER_SHARED_SECRET`
   - `GOOGLE_PLAY_VERIFICATION_MODE=broker`
   - `GOOGLE_PLAY_PACKAGE_NAME`
3. Deploy the Worker.
4. Configure a Pub/Sub push subscription to:
   - `https://<cloud-run-url>/google-play/rtdn`
5. Test:
   - one `/api/subscriptions/google/verify` request from Android
   - one `/google-play/reconcile` request to Cloud Run
   - one RTDN delivery through Pub/Sub

## Notes

- The Cloud Run service is intentionally public because Google Pub/Sub push and the Worker need to reach it. Request authenticity is enforced by the shared HMAC secret for `/google-play/verify` and `/google-play/reconcile`.
- Do not remove `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` from the Worker until the broker path is live and verified.
