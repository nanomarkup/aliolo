#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."
SERVICE_DIR="$PROJECT_ROOT/google-play-verifier"

required_vars=(
  GCP_PROJECT_ID
  GCP_REGION
  GOOGLE_PLAY_VERIFIER_SERVICE
  GOOGLE_PLAY_PACKAGE_NAME
  WORKER_SHARED_SECRET
  WORKER_GOOGLE_PLAY_WEBHOOK_URL
  WORKER_GOOGLE_PLAY_RECONCILE_CANDIDATES_URL
  GOOGLE_PLAY_VERIFIER_SERVICE_ACCOUNT
)

for var_name in "${required_vars[@]}"; do
  if [ -z "${!var_name:-}" ]; then
    echo "Missing required environment variable: $var_name" >&2
    exit 1
  fi
done

IMAGE="gcr.io/${GCP_PROJECT_ID}/${GOOGLE_PLAY_VERIFIER_SERVICE}"

echo "Building container image: $IMAGE"
gcloud builds submit "$SERVICE_DIR" \
  --project="$GCP_PROJECT_ID" \
  --tag="$IMAGE"

echo "Deploying Cloud Run service: $GOOGLE_PLAY_VERIFIER_SERVICE"
gcloud run deploy "$GOOGLE_PLAY_VERIFIER_SERVICE" \
  --project="$GCP_PROJECT_ID" \
  --region="$GCP_REGION" \
  --image="$IMAGE" \
  --service-account="$GOOGLE_PLAY_VERIFIER_SERVICE_ACCOUNT" \
  --allow-unauthenticated \
  --port=8080 \
  --set-env-vars="GOOGLE_PLAY_PACKAGE_NAME=${GOOGLE_PLAY_PACKAGE_NAME},WORKER_SHARED_SECRET=${WORKER_SHARED_SECRET},WORKER_GOOGLE_PLAY_WEBHOOK_URL=${WORKER_GOOGLE_PLAY_WEBHOOK_URL},WORKER_GOOGLE_PLAY_RECONCILE_CANDIDATES_URL=${WORKER_GOOGLE_PLAY_RECONCILE_CANDIDATES_URL}"

echo ""
echo "Cloud Run service deployed."
echo "Next:"
echo "1. Configure Pub/Sub push to https://<service-url>/google-play/rtdn"
echo "2. Set Worker env vars GOOGLE_PLAY_VERIFIER_URL and GOOGLE_PLAY_VERIFIER_SHARED_SECRET"
echo "3. Deploy the Worker with GOOGLE_PLAY_VERIFICATION_MODE=broker"
