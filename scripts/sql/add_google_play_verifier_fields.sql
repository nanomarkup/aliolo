ALTER TABLE provider_subscriptions ADD COLUMN google_obfuscated_account_id TEXT;
ALTER TABLE provider_subscriptions ADD COLUMN last_verification_source TEXT;
ALTER TABLE provider_subscriptions ADD COLUMN last_verified_at TEXT;

ALTER TABLE subscription_events ADD COLUMN source TEXT;
ALTER TABLE subscription_events ADD COLUMN external_notification_id TEXT;

CREATE INDEX IF NOT EXISTS idx_provider_subscriptions_google_obfuscated_account_id
  ON provider_subscriptions(provider, google_obfuscated_account_id);

CREATE INDEX IF NOT EXISTS idx_provider_subscriptions_purchase_token
  ON provider_subscriptions(provider, purchase_token);

CREATE INDEX IF NOT EXISTS idx_subscription_events_provider_source
  ON subscription_events(provider, source);

CREATE TABLE IF NOT EXISTS pending_purchase_intents (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES profiles(id),
  provider TEXT NOT NULL,
  product_id TEXT NOT NULL,
  package_name TEXT,
  google_obfuscated_account_id TEXT,
  platform TEXT,
  purchase_token TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  raw_payload TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_pending_purchase_intents_user_provider
  ON pending_purchase_intents(user_id, provider, status);

CREATE INDEX IF NOT EXISTS idx_pending_purchase_intents_google_obfuscated
  ON pending_purchase_intents(provider, google_obfuscated_account_id, status);

DELETE FROM pending_purchase_intents
WHERE id IN (
  SELECT duplicate.id
  FROM pending_purchase_intents AS duplicate
  JOIN pending_purchase_intents AS latest
    ON latest.user_id = duplicate.user_id
   AND latest.provider = duplicate.provider
   AND latest.status = duplicate.status
   AND (
     datetime(latest.updated_at) > datetime(duplicate.updated_at)
     OR (
       datetime(latest.updated_at) = datetime(duplicate.updated_at)
       AND datetime(latest.created_at) > datetime(duplicate.created_at)
     )
     OR (
       datetime(latest.updated_at) = datetime(duplicate.updated_at)
       AND datetime(latest.created_at) = datetime(duplicate.created_at)
       AND latest.id > duplicate.id
     )
   )
  WHERE duplicate.provider = 'google_play'
    AND duplicate.status = 'pending'
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_pending_purchase_intents_one_pending_per_user
  ON pending_purchase_intents(user_id, provider)
  WHERE status = 'pending';
