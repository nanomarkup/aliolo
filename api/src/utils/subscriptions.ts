export type ProviderName = 'google_play' | 'app_store' | 'paddle';
export type EntitlementSource = 'provider' | 'manual' | 'none';

type ProviderSubscriptionRow = {
  id: string;
  provider: ProviderName;
  product_id: string | null;
  current_period_end: string | null;
  created_at: string | null;
  updated_at: string | null;
};

type ManualGrantRow = {
  id: string;
  ends_at: string | null;
  created_at: string | null;
  updated_at: string | null;
};

export type EffectiveSubscription = {
  id: string | null;
  user_id: string;
  status: 'active' | 'inactive';
  effective_source: EntitlementSource;
  provider: ProviderName | 'aliolo_manual' | null;
  product_id: string | null;
  effective_until: string | null;
  expiry_date: string | null;
  purchase_token: null;
  order_id: null;
  active_provider_subscription_id: string | null;
  active_manual_grant_id: string | null;
  created_at: string | null;
  updated_at: string | null;
};

function isFutureOrOpen(value: string | null | undefined): boolean {
  if (!value) return true;
  return new Date(value).getTime() > Date.now();
}

function laterDate(a: string | null, b: string | null): string | null {
  if (!a || !b) return null;
  return new Date(a).getTime() >= new Date(b).getTime() ? a : b;
}

export async function recomputeUserSubscription(
  db: D1Database,
  userId: string,
): Promise<EffectiveSubscription> {
  const provider = await db.prepare(`
    SELECT id, provider, product_id, current_period_end, created_at, updated_at
    FROM provider_subscriptions
    WHERE user_id = ?
      AND status IN ('active', 'trialing')
      AND (current_period_end IS NULL OR datetime(current_period_end) > CURRENT_TIMESTAMP)
    ORDER BY
      CASE WHEN current_period_end IS NULL THEN 1 ELSE 0 END DESC,
      datetime(current_period_end) DESC
    LIMIT 1
  `).bind(userId).first<ProviderSubscriptionRow>();

  const manual = await db.prepare(`
    SELECT id, ends_at, created_at, updated_at
    FROM manual_subscription_grants
    WHERE user_id = ?
      AND status = 'active'
      AND (starts_at IS NULL OR datetime(starts_at) <= CURRENT_TIMESTAMP)
      AND (ends_at IS NULL OR datetime(ends_at) > CURRENT_TIMESTAMP)
    ORDER BY
      CASE WHEN ends_at IS NULL THEN 1 ELSE 0 END DESC,
      datetime(ends_at) DESC
    LIMIT 1
  `).bind(userId).first<ManualGrantRow>();

  let status = 'inactive';
  let effectiveSource: EntitlementSource = 'none';
  let snapshotProvider: ProviderName | 'aliolo_manual' | null = null;
  let productId: string | null = null;
  let effectiveUntil: string | null = null;
  let activeProviderSubscriptionId: string | null = null;
  let activeManualGrantId: string | null = null;
  let subscriptionId: string | null = null;
  let createdAt: string | null = null;
  let updatedAt: string | null = null;

  if (provider && isFutureOrOpen(provider.current_period_end)) {
    status = 'active';
    effectiveSource = 'provider';
    snapshotProvider = provider.provider;
    productId = provider.product_id;
    effectiveUntil = provider.current_period_end;
    activeProviderSubscriptionId = provider.id;
    subscriptionId = provider.id;
    createdAt = provider.created_at;
    updatedAt = provider.updated_at;
  }

  if (manual && isFutureOrOpen(manual.ends_at)) {
    const manualWins =
      status !== 'active' ||
      manual.ends_at === null ||
      (effectiveUntil !== null &&
        new Date(manual.ends_at).getTime() > new Date(effectiveUntil).getTime());

    if (manualWins) {
      effectiveSource = 'manual';
      snapshotProvider = 'aliolo_manual';
      productId = null;
      activeProviderSubscriptionId = provider?.id ?? null;
      subscriptionId = manual.id;
      createdAt = manual.created_at;
      updatedAt = manual.updated_at;
    }

    status = 'active';
    effectiveUntil = laterDate(effectiveUntil, manual.ends_at);
    activeManualGrantId = manual.id;
    if (!subscriptionId) subscriptionId = manual.id;
    if (!createdAt) createdAt = manual.created_at;
    if (!updatedAt) updatedAt = manual.updated_at;
  }

  await db.prepare(`
    UPDATE profiles
    SET is_premium = ?, updated_at = CURRENT_TIMESTAMP
    WHERE id = ?
  `).bind(status === 'active' ? 1 : 0, userId).run();

  return {
    id: subscriptionId,
    user_id: userId,
    status: status as 'active' | 'inactive',
    effective_source: effectiveSource,
    provider: snapshotProvider,
    product_id: productId,
    effective_until: effectiveUntil,
    expiry_date: effectiveUntil,
    purchase_token: null,
    order_id: null,
    active_provider_subscription_id: activeProviderSubscriptionId,
    active_manual_grant_id: activeManualGrantId,
    created_at: createdAt,
    updated_at: updatedAt,
  };
}

export async function recordSubscriptionEvent(
  db: D1Database,
  args: {
    id: string;
    userId: string;
    provider: ProviderName | 'aliolo_manual';
    eventType: string;
    externalSubscriptionId?: string | null;
    externalTransactionId?: string | null;
    productId?: string | null;
    rawEvent?: unknown;
  },
) {
  const existing = await db.prepare(
    'SELECT id FROM subscription_events WHERE id = ?'
  ).bind(args.id).first();

  if (existing) return false;

  await db.prepare(`
    INSERT INTO subscription_events (
      id,
      user_id,
      provider,
      event_type,
      external_subscription_id,
      external_transaction_id,
      product_id,
      raw_event,
      created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
  `).bind(
    args.id,
    args.userId,
    args.provider,
    args.eventType,
    args.externalSubscriptionId ?? null,
    args.externalTransactionId ?? null,
    args.productId ?? null,
    args.rawEvent == null ? null : JSON.stringify(args.rawEvent),
  ).run();

  return true;
}
