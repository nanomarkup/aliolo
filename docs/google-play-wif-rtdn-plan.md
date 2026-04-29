# Best-Practice Google Play Subscription Architecture for Aliolo

## Summary
Migrate Aliolo's Android subscription handling to a full server-driven model:

- **Google Play Billing** remains the purchase processor on Android.
- **Cloudflare Worker** remains Aliolo's main API and entitlement owner.
- A small **Google-hosted verifier/ingestion service** handles Android Publisher and Pub/Sub access with an attached service account, not a JSON key.
- **Google RTDN** becomes the primary lifecycle signal for renewals, cancellations, holds, grace periods, revocations, and expirations.
- **Client-triggered verify** remains as a fast-path for immediate entitlement after purchase restore/buy flows.
- A scheduled **reconciliation job** backfills missed events, repairs drift, and normalizes old records.

This replaces key-based runtime auth with keyless Google-hosted auth and upgrades Aliolo from "verify on demand" to "verify + webhook + reconciliation".

## Key Changes
- Add a Google-hosted service, preferably **Cloud Run**, with three responsibilities:
  - `POST /google-play/verify` for on-demand verification from the Worker
  - `POST /google-play/rtdn` for Pub/Sub push delivery of Real-time Developer Notifications
  - `POST /google-play/reconcile` for targeted or batch reconciliation runs
- Use an attached Google service account on Cloud Run with Android Publisher and Pub/Sub access. Do not create or store service-account JSON anywhere in Cloudflare or GitHub for runtime.

- Keep the Worker as the entitlement system of record.
  - The Worker continues to own `provider_subscriptions`, `subscription_events`, and `profiles.is_premium`.
  - The Worker stops calling Google directly.
  - The Worker accepts normalized subscription updates only from the verifier service.

- Introduce a signed internal ingestion contract between Cloud Run and the Worker.
  - Cloud Run sends normalized Google subscription events to a dedicated Worker endpoint.
  - Use HMAC signing with timestamped requests.
  - The Worker validates signature, rejects replay, stores the event, upserts `provider_subscriptions`, and recomputes premium state.

- Make **RTDN** the primary background signal.
  - Cloud Run receives Pub/Sub push notifications from Google.
  - For each RTDN message, Cloud Run fetches the latest subscription state from Android Publisher instead of trusting the notification alone.
  - Cloud Run transforms the latest Google state into Aliolo's normalized subscription event shape and forwards it to the Worker.

- Keep **client verify** for immediate UX.
  - `/api/subscriptions/google/verify` stays in the Worker.
  - Instead of direct Google auth, it calls Cloud Run `/google-play/verify`.
  - This grants entitlement immediately after purchase, restore, or app reinstall, without waiting for RTDN.

- Add **reconciliation**.
  - Scheduled job runs at least daily, ideally every few hours.
  - Reconcile active and recently changed Google Play subscriptions already known to Aliolo.
  - Re-query Android Publisher for subscriptions in states that commonly drift: active, grace period, on hold, paused-like inactive states, recently expired, recently revoked.
  - Re-emit normalized updates into the same Worker ingestion path used by RTDN so all state changes go through one code path.

- Add **stable user correlation** for Google Play.
  - Android client must set `obfuscatedAccountId` to a stable Aliolo user-derived identifier when launching the Billing purchase flow.
  - Treat this as the primary mapping key for RTDN-era updates.
  - Keep purchase-token-based fallback only for legacy subscriptions already created before this rollout.

## Interfaces and Data Model
- New Worker env vars:
  - `GOOGLE_PLAY_VERIFIER_URL`
  - `GOOGLE_PLAY_VERIFIER_SHARED_SECRET`
  - optional `GOOGLE_PLAY_VERIFICATION_MODE=broker|mock`
- Remove non-test reliance on `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`.

- New Worker endpoint for trusted server ingestion:
  - `POST /api/subscriptions/google/webhook`
  - Request source: Cloud Run only
  - Auth: `X-Aliolo-Timestamp` and `X-Aliolo-Signature`
  - Body contains normalized event plus current verified subscription snapshot

- New Cloud Run endpoints:
  - `POST /google-play/verify`
  - `POST /google-play/rtdn`
  - `POST /google-play/reconcile`

- Extend `provider_subscriptions` to better support RTDN and repair flows.
  - Add a stable field for Google account linkage, preferably `google_obfuscated_account_id`
  - Add a field for last verified source, for example `last_verification_source` with values like `client_verify`, `rtdn`, `reconcile`
  - Add `last_verified_at`
  - Keep `external_subscription_id = purchaseToken` unless a better immutable Google identifier is introduced later
- Extend `subscription_events` to store source and dedupe metadata.
  - Add `source`
  - Add Google notification identifiers where available
  - Keep idempotency on event id
- Preserve current entitlement computation in `recomputeUserSubscription`; do not fork business logic by source.

## Event and State Handling
- Normalize Google subscription states centrally in Cloud Run, not in multiple places.
  - Active and grace period map to active entitlement.
  - On-hold, revoked, expired, canceled-with-period-ended map to inactive.
  - Auto-renew and current-period-end are carried through explicitly.
- RTDN processing flow:
  1. Pub/Sub pushes message to Cloud Run.
  2. Cloud Run validates the push source.
  3. Cloud Run parses notification type and purchase token.
  4. Cloud Run calls Android Publisher to fetch the full latest subscription.
  5. Cloud Run resolves Aliolo user from `obfuscatedExternalAccountId` first, then purchase-token fallback if necessary.
  6. Cloud Run forwards one normalized event to the Worker.
  7. Worker records idempotent event, upserts subscription row, recomputes premium, and returns success.
- Client verify flow:
  1. App posts purchase token and product id to Worker.
  2. Worker calls Cloud Run verify endpoint.
  3. Cloud Run verifies against Android Publisher and returns normalized snapshot.
  4. Worker upserts and recomputes premium using the same shared update logic as RTDN.
- Reconciliation flow:
  1. Scheduler triggers Cloud Run reconcile endpoint.
  2. Cloud Run obtains candidates from the Worker or a targeted input list.
  3. Cloud Run re-verifies subscriptions with Android Publisher.
  4. Cloud Run forwards normalized updates to the Worker through the same ingestion endpoint.
  5. Worker processes idempotently.

## Testing and Acceptance
- Worker tests:
  - client verify still activates subscription through brokered verification
  - trusted Google webhook ingestion updates `provider_subscriptions` and `profiles.is_premium`
  - duplicate RTDN-derived events are ignored safely
  - invalid HMAC or expired timestamp is rejected
  - reconciliation-driven updates use the same persistence path as RTDN
  - mock mode still works in local tests
- Cloud Run tests:
  - Android Publisher responses normalize correctly for active, grace period, on hold, expired, revoked, and mismatched product cases
  - RTDN push parsing extracts purchase token and notification type correctly
  - user resolution prefers `obfuscatedExternalAccountId`
  - ingestion retries are safe on Worker 5xx and do not create duplicates on retry
- Android acceptance:
  - new purchases set `obfuscatedAccountId`
  - purchase restore works through client verify
- End-to-end acceptance:
  - purchase grants premium quickly through verify
  - renewal/cancel/refund/hold transitions update premium through RTDN without client interaction
  - missed RTDN can be repaired by reconciliation
  - no runtime Google JSON key exists in Cloudflare
  - no Play upload JSON key exists in GitHub after CI WIF migration

## Assumptions and Defaults
- Cloud Run is the Google-side runtime used for Android Publisher and Pub/Sub handling.
- Google Pub/Sub push delivery is acceptable for RTDN ingestion.
- Aliolo will keep Cloudflare Worker as the main API and entitlement owner rather than moving subscription state fully into Google Cloud.
- Android client changes are in scope to set `obfuscatedAccountId`.
- Client verify remains enabled for immediate UX; RTDN and reconciliation are additive, not replacements.
- Legacy subscriptions without `obfuscatedAccountId` are supported via purchase-token fallback during migration, but new purchases must use the obfuscated account identifier path.
