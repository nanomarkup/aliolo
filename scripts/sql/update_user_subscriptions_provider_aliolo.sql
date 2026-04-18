UPDATE user_subscriptions
SET provider = 'aliolo',
    updated_at = CURRENT_TIMESTAMP
WHERE provider IS NULL OR provider <> 'aliolo';
