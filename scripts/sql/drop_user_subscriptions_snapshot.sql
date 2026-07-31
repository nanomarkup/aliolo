UPDATE profiles
SET is_premium = CASE
  WHEN EXISTS (
    SELECT 1
    FROM provider_subscriptions ps
    WHERE ps.user_id = profiles.id
      AND ps.status IN ('active', 'trialing')
      AND (ps.current_period_end IS NULL OR datetime(ps.current_period_end) > CURRENT_TIMESTAMP)
  )
  OR EXISTS (
    SELECT 1
    FROM manual_subscription_grants msg
    WHERE msg.user_id = profiles.id
      AND msg.status = 'active'
      AND (msg.starts_at IS NULL OR datetime(msg.starts_at) <= CURRENT_TIMESTAMP)
      AND (msg.ends_at IS NULL OR datetime(msg.ends_at) > CURRENT_TIMESTAMP)
  )
  THEN 1
  ELSE 0
END,
updated_at = CURRENT_TIMESTAMP;

DROP TABLE IF EXISTS user_subscriptions;
