import { OpenAPIHono } from '@hono/zod-openapi';
import { generateId } from 'lucia';
import type { AppEnv } from '../types';
import {
    GooglePlayVerificationError,
    getSharedRequestHeaders,
    type GooglePlaySubscriptionVerification,
    type GooglePlayWebhookPayload,
    validateSignedRequest,
    verifyGooglePlaySubscription,
} from '../utils/google-play';
import {
    recomputeUserSubscription,
    recordSubscriptionEvent,
    type ProviderName,
    upsertProviderSubscription,
} from '../utils/subscriptions';

const router = new OpenAPIHono<AppEnv>();

const productDurations: Record<string, number> = {
    aliolo_premium_weekly: 7,
    aliolo_premium_monthly: 31,
    aliolo_premium_yearly: 366,
};

function addDays(days: number): string {
    return new Date(Date.now() + days * 24 * 60 * 60 * 1000).toISOString();
}

function providerPayload(body: any, provider: ProviderName) {
    const productId = body.productId ?? body.product_id ?? null;
    const externalSubscriptionId =
        body.subscriptionId ??
        body.subscription_id ??
        body.originalTransactionId ??
        body.purchaseToken ??
        body.purchase_token ??
        body.transactionId ??
        body.transaction_id ??
        null;
    const externalTransactionId =
        body.orderId ?? body.order_id ?? body.transactionId ?? body.transaction_id ?? null;
    const purchaseToken = body.purchaseToken ?? body.purchase_token ?? null;
    const periodEnd =
        body.expiryDate ??
        body.expiry_date ??
        body.currentPeriodEnd ??
        body.current_period_end ??
        (productId ? addDays(productDurations[productId] ?? 31) : null);

    return {
        provider,
        status: body.status ?? 'active',
        productId,
        externalSubscriptionId,
        externalCustomerId: body.customerId ?? body.customer_id ?? null,
        externalTransactionId,
        purchaseToken,
        environment: body.environment ?? null,
        periodStart: body.currentPeriodStart ?? body.current_period_start ?? null,
        periodEnd,
        willRenew: body.willRenew ?? body.will_renew ?? null,
        googleObfuscatedAccountId:
            body.googleObfuscatedAccountId ??
            body.google_obfuscated_account_id ??
            body.customerId ??
            body.customer_id ??
            null,
    };
}

function isMockVerification(c: any): boolean {
    return c.env.SUBSCRIPTION_VERIFICATION_MODE === 'mock' || c.env.ENVIRONMENT === 'test';
}

function isMockGoogleVerification(c: any): boolean {
    return c.env.SUBSCRIPTION_VERIFICATION_MODE === 'mock'
        || (c.env.ENVIRONMENT === 'test' && !c.env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON);
}

function paddlePriceId(c: any, productId: string): string | null {
    if (productId === 'aliolo_premium_weekly') return c.env.PADDLE_PRICE_WEEKLY ?? null;
    if (productId === 'aliolo_premium_monthly') return c.env.PADDLE_PRICE_MONTHLY ?? null;
    if (productId === 'aliolo_premium_yearly') return c.env.PADDLE_PRICE_YEARLY ?? null;
    return null;
}

function hex(buffer: ArrayBuffer): string {
    return [...new Uint8Array(buffer)]
        .map((value) => value.toString(16).padStart(2, '0'))
        .join('');
}

async function verifyPaddleSignature(rawBody: string, signatureHeader: string | undefined, secret: string | undefined) {
    if (!secret) return false;
    if (!signatureHeader) return false;

    const parts = Object.fromEntries(
        signatureHeader.split(';').map((part) => {
            const [key, value] = part.split('=');
            return [key?.trim(), value?.trim()];
        }),
    );
    const timestamp = parts.ts;
    const signature = parts.h1;
    if (!timestamp || !signature) return false;

    const key = await crypto.subtle.importKey(
        'raw',
        new TextEncoder().encode(secret),
        { name: 'HMAC', hash: 'SHA-256' },
        false,
        ['sign'],
    );
    const digest = await crypto.subtle.sign(
        'HMAC',
        key,
        new TextEncoder().encode(`${timestamp}:${rawBody}`),
    );
    return hex(digest) === signature;
}

async function persistProviderSubscription(
    db: D1Database,
    userId: string,
    payload: ReturnType<typeof providerPayload>,
    rawPayload: unknown,
    options?: {
        source?: 'client_verify' | 'rtdn' | 'reconcile' | 'paddle_webhook';
        verifiedAt?: string | null;
    },
) {
    await upsertProviderSubscription(db, {
        userId,
        provider: payload.provider,
        status: payload.status,
        externalSubscriptionId: payload.externalSubscriptionId,
        externalCustomerId: payload.externalCustomerId,
        externalTransactionId: payload.externalTransactionId,
        purchaseToken: payload.purchaseToken,
        productId: payload.productId,
        environment: payload.environment,
        periodStart: payload.periodStart,
        periodEnd: payload.periodEnd,
        willRenew: payload.willRenew,
        rawPayload,
        googleObfuscatedAccountId: payload.googleObfuscatedAccountId,
        lastVerificationSource: options?.source ?? null,
        lastVerifiedAt: options?.verifiedAt ?? null,
    });

    await recomputeUserSubscription(db, userId);
}

function providerPayloadFromGoogleVerification(
    body: any,
    verification: GooglePlaySubscriptionVerification,
) {
    return providerPayload({
        ...body,
        status: verification.status,
        productId: verification.productId,
        subscriptionId: verification.externalSubscriptionId,
        customerId: verification.externalCustomerId,
        orderId: verification.externalTransactionId,
        purchaseToken: verification.purchaseToken,
        environment: verification.environment,
        currentPeriodStart: verification.periodStart,
        currentPeriodEnd: verification.periodEnd,
        willRenew: verification.willRenew,
        subscriptionState: verification.subscriptionState,
        packageName: verification.packageName,
        googleObfuscatedAccountId:
            body.googleObfuscatedAccountId ??
            body.google_obfuscated_account_id ??
            verification.externalCustomerId,
    }, 'google_play');
}

async function resolveGooglePlayUserId(
    db: D1Database,
    args: {
        userId?: string | null;
        googleObfuscatedAccountId?: string | null;
        purchaseToken?: string | null;
    },
): Promise<string | null> {
    if (args.userId) {
        const profile = await db.prepare('SELECT id FROM profiles WHERE id = ?')
            .bind(args.userId)
            .first<{ id: string }>();
        if (profile?.id) return profile.id;
    }

    if (args.googleObfuscatedAccountId) {
        const linkedProfile = await db.prepare(`
            SELECT user_id
            FROM provider_subscriptions
            WHERE provider = 'google_play'
              AND (
                google_obfuscated_account_id = ?
                OR external_customer_id = ?
              )
            ORDER BY datetime(updated_at) DESC
            LIMIT 1
        `).bind(args.googleObfuscatedAccountId, args.googleObfuscatedAccountId).first<{ user_id: string }>();
        if (linkedProfile?.user_id) return linkedProfile.user_id;

        const pendingIntent = await db.prepare(`
            SELECT user_id
            FROM pending_purchase_intents
            WHERE provider = 'google_play'
              AND google_obfuscated_account_id = ?
              AND status = 'pending'
            ORDER BY datetime(updated_at) DESC
            LIMIT 1
        `).bind(args.googleObfuscatedAccountId).first<{ user_id: string }>();
        if (pendingIntent?.user_id) return pendingIntent.user_id;
    }

    if (args.purchaseToken) {
        const linkedProfile = await db.prepare(`
            SELECT user_id
            FROM provider_subscriptions
            WHERE provider = 'google_play'
              AND (
                purchase_token = ?
                OR external_subscription_id = ?
              )
            ORDER BY datetime(updated_at) DESC
            LIMIT 1
        `).bind(args.purchaseToken, args.purchaseToken).first<{ user_id: string }>();
        if (linkedProfile?.user_id) return linkedProfile.user_id;
    }

    return null;
}

async function createPendingGooglePurchaseIntent(
    db: D1Database,
    args: {
        userId: string;
        productId: string;
        packageName?: string | null;
        googleObfuscatedAccountId?: string | null;
        platform?: string | null;
        rawPayload?: unknown;
    },
) {
    const rawPayload = args.rawPayload == null ? null : JSON.stringify(args.rawPayload);

    await db.prepare(`
        UPDATE pending_purchase_intents
        SET
            product_id = ?,
            package_name = ?,
            google_obfuscated_account_id = ?,
            platform = ?,
            raw_payload = ?,
            updated_at = CURRENT_TIMESTAMP
        WHERE id IN (
            SELECT id
            FROM pending_purchase_intents
            WHERE user_id = ?
              AND provider = 'google_play'
              AND status = 'pending'
            ORDER BY datetime(updated_at) DESC, datetime(created_at) DESC
            LIMIT 1
        )
    `).bind(
        args.productId,
        args.packageName ?? null,
        args.googleObfuscatedAccountId ?? null,
        args.platform ?? null,
        rawPayload,
        args.userId,
    ).run();

    const pendingIntent = await db.prepare(`
        SELECT id
        FROM pending_purchase_intents
        WHERE user_id = ?
          AND provider = 'google_play'
          AND status = 'pending'
        ORDER BY datetime(updated_at) DESC, datetime(created_at) DESC
        LIMIT 1
    `).bind(args.userId).first<{ id: string }>();

    if (pendingIntent?.id) {
        return;
    }

    await db.prepare(`
        INSERT INTO pending_purchase_intents (
            id,
            user_id,
            provider,
            product_id,
            package_name,
            google_obfuscated_account_id,
            platform,
            status,
            raw_payload,
            created_at,
            updated_at
        ) VALUES (?, ?, 'google_play', ?, ?, ?, ?, 'pending', ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    `).bind(
        generateId(15),
        args.userId,
        args.productId,
        args.packageName ?? null,
        args.googleObfuscatedAccountId ?? null,
        args.platform ?? null,
        rawPayload,
    ).run();
}

async function markPendingGooglePurchaseIntentVerified(
    db: D1Database,
    args: {
        userId: string;
        productId?: string | null;
        purchaseToken?: string | null;
        googleObfuscatedAccountId?: string | null;
        rawPayload?: unknown;
    },
) {
    await db.prepare(`
        UPDATE pending_purchase_intents
        SET
            purchase_token = COALESCE(?, purchase_token),
            status = 'verified',
            raw_payload = COALESCE(?, raw_payload),
            updated_at = CURRENT_TIMESTAMP
        WHERE id IN (
            SELECT id
            FROM pending_purchase_intents
            WHERE user_id = ?
              AND provider = 'google_play'
              AND status = 'pending'
              AND (? IS NULL OR product_id = ?)
              AND (? IS NULL OR google_obfuscated_account_id = ?)
            ORDER BY datetime(created_at) DESC
            LIMIT 1
        )
    `).bind(
        args.purchaseToken ?? null,
        args.rawPayload == null ? null : JSON.stringify(args.rawPayload),
        args.userId,
        args.productId ?? null,
        args.productId ?? null,
        args.googleObfuscatedAccountId ?? null,
        args.googleObfuscatedAccountId ?? null,
    ).run();
}

async function handleGoogleVerify(
    c: any,
    userId: string,
    body: any,
) {
    const token = body.purchaseToken ?? body.purchase_token;
    const productId = body.productId ?? body.product_id;
    const packageName = body.packageName ?? body.package_name ?? null;
    if (!token || !productId) {
        return c.json({ error: 'purchaseToken and productId are required' }, 400);
    }

    const eventType = body.eventType ?? body.event_type ?? 'client_verify';
    const eventSource = eventType === 'restore_claim' ? 'reconcile' : 'client_verify';

    if (isMockGoogleVerification(c)) {
        const payload = providerPayload(body, 'google_play');
        await persistProviderSubscription(c.env.DB, userId, payload, body, {
            source: eventSource,
            verifiedAt: new Date().toISOString(),
        });
        await recordSubscriptionEvent(c.env.DB, {
            id: body.eventId ?? `google_${token}`,
            userId,
            provider: 'google_play',
            eventType,
            externalSubscriptionId: payload.externalSubscriptionId,
            externalTransactionId: payload.externalTransactionId,
            productId,
            source: eventSource,
            rawEvent: body,
        });

        return c.json({ success: true });
    }

    try {
        const verification = await verifyGooglePlaySubscription(c.env, {
            purchaseToken: token,
            productId,
            packageName,
            source: 'client_verify',
            googleObfuscatedAccountId:
                body.googleObfuscatedAccountId ??
                body.google_obfuscated_account_id ??
                null,
        });
        const payload = providerPayloadFromGoogleVerification(body, verification);
        await persistProviderSubscription(c.env.DB, userId, payload, verification.rawPayload, {
            source: eventSource,
            verifiedAt: new Date().toISOString(),
        });
        await markPendingGooglePurchaseIntentVerified(c.env.DB, {
            userId,
            productId: verification.productId,
            purchaseToken: verification.purchaseToken,
            googleObfuscatedAccountId:
                body.googleObfuscatedAccountId ??
                body.google_obfuscated_account_id ??
                verification.externalCustomerId,
            rawPayload: verification.rawPayload,
        });
        await recordSubscriptionEvent(c.env.DB, {
            id: body.eventId ?? `google_${token}_${verification.externalTransactionId ?? 'verify'}`,
            userId,
            provider: 'google_play',
            eventType,
            externalSubscriptionId: payload.externalSubscriptionId,
            externalTransactionId: payload.externalTransactionId,
            productId: verification.productId,
            source: eventSource,
            rawEvent: verification.rawPayload,
        });

        return c.json({
            success: true,
            product_id: verification.productId,
            status: verification.status,
            current_period_end: verification.periodEnd,
            will_renew: verification.willRenew,
        });
    } catch (error) {
        if (error instanceof GooglePlayVerificationError) {
            return c.json({ error: error.message }, error.status as any);
        }
        throw error;
    }
}

router.get('/', async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    try {
        const result = await recomputeUserSubscription(c.env.DB, user.id);
        return c.json(result);
    } catch (e: any) {
        return c.json({ error: e.message }, 500);
    }
});

router.post('/google/purchase-intent', async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const body = await c.req.json().catch(() => ({}));
    const productId = body.productId ?? body.product_id;
    if (!productId) return c.json({ error: 'productId is required' }, 400);

    await createPendingGooglePurchaseIntent(c.env.DB, {
        userId: user.id,
        productId,
        packageName: body.packageName ?? body.package_name ?? null,
        googleObfuscatedAccountId:
            body.googleObfuscatedAccountId ??
            body.google_obfuscated_account_id ??
            null,
        platform: body.platform ?? 'android',
        rawPayload: body,
    });

    return c.json({ success: true });
});

router.post('/google/verify', async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const body = await c.req.json().catch(() => ({}));
    return handleGoogleVerify(c, user.id, body);
});

router.post('/google/claim-restored', async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const body = await c.req.json().catch(() => ({}));
    body.eventType = 'restore_claim';
    body.eventId ??= `google_restore_${body.purchaseToken ?? body.purchase_token ?? Date.now()}`;
    return handleGoogleVerify(c, user.id, body);
});

router.post('/google/webhook', async (c) => {
    const rawBody = await c.req.text();
    const headers = getSharedRequestHeaders();
    const valid = await validateSignedRequest(
        c.env.GOOGLE_PLAY_VERIFIER_SHARED_SECRET,
        rawBody,
        c.req.header(headers.signature),
        c.req.header(headers.timestamp),
    );
    if (!valid) return c.json({ error: 'Invalid Google Play verifier signature' }, 401);

    const body = JSON.parse(rawBody || '{}') as Partial<GooglePlayWebhookPayload>;
    const verification = body.verification;
    if (!body.eventId || !body.eventType || !body.source || !verification?.purchaseToken) {
        return c.json({ error: 'Invalid Google Play webhook payload' }, 400);
    }

    const googleObfuscatedAccountId =
        body.googleObfuscatedAccountId ??
        verification.externalCustomerId ??
        null;
    const userId = await resolveGooglePlayUserId(c.env.DB, {
        userId: body.userId ?? null,
        googleObfuscatedAccountId,
        purchaseToken: body.purchaseToken ?? verification.purchaseToken,
    });
    if (!userId) {
        return c.json({ success: true, ignored: true, reason: 'user_not_found' }, 202);
    }

    const inserted = await recordSubscriptionEvent(c.env.DB, {
        id: body.eventId,
        userId,
        provider: 'google_play',
        eventType: body.eventType,
        externalSubscriptionId: verification.externalSubscriptionId,
        externalTransactionId: verification.externalTransactionId,
        productId: verification.productId,
        source: body.source,
        externalNotificationId: body.externalNotificationId ?? null,
        rawEvent: body.rawEvent ?? verification.rawPayload,
    });
    if (!inserted) {
        return c.json({ success: true, duplicate: true });
    }

    const payload = providerPayloadFromGoogleVerification({
        purchaseToken: verification.purchaseToken,
        productId: verification.productId,
        packageName: verification.packageName,
        googleObfuscatedAccountId,
    }, verification);
    await persistProviderSubscription(c.env.DB, userId, payload, verification.rawPayload, {
        source: body.source,
        verifiedAt: new Date().toISOString(),
    });

    return c.json({ success: true });
});

router.get('/google/reconcile-candidates', async (c) => {
    const headers = getSharedRequestHeaders();
    const valid = await validateSignedRequest(
        c.env.GOOGLE_PLAY_VERIFIER_SHARED_SECRET,
        '',
        c.req.header(headers.signature),
        c.req.header(headers.timestamp),
    );
    if (!valid) return c.json({ error: 'Invalid Google Play verifier signature' }, 401);

    const requestedLimit = Number(c.req.query('limit') ?? '200');
    const limit = Number.isFinite(requestedLimit)
        ? Math.max(1, Math.min(500, Math.floor(requestedLimit)))
        : 200;
    const candidates = await c.env.DB.prepare(`
        SELECT
            user_id,
            purchase_token,
            product_id,
            COALESCE(google_obfuscated_account_id, external_customer_id) AS google_obfuscated_account_id
        FROM provider_subscriptions
        WHERE provider = 'google_play'
          AND purchase_token IS NOT NULL
          AND (
            current_period_end IS NULL
            OR datetime(current_period_end) >= datetime('now', '-35 days')
          )
        ORDER BY datetime(updated_at) DESC
        LIMIT ?
    `).bind(limit).all<{
        user_id: string;
        purchase_token: string;
        product_id: string | null;
        google_obfuscated_account_id: string | null;
    }>();

    return c.json({
        subscriptions: (candidates.results ?? []).map((row) => ({
            userId: row.user_id,
            purchaseToken: row.purchase_token,
            productId: row.product_id,
            packageName: c.env.GOOGLE_PLAY_PACKAGE_NAME ?? null,
            googleObfuscatedAccountId: row.google_obfuscated_account_id,
        })),
    });
});

router.post('/apple/verify', async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const body = await c.req.json().catch(() => ({}));
    const transactionId = body.transactionId ?? body.transaction_id;
    const productId = body.productId ?? body.product_id;
    if (!transactionId || !productId) {
        return c.json({ error: 'transactionId and productId are required' }, 400);
    }

    if (!isMockVerification(c)) {
        return c.json({ error: 'Apple Store verification is not configured' }, 503);
    }

    const payload = providerPayload(body, 'app_store');
    await persistProviderSubscription(c.env.DB, user.id, payload, body, {
        source: 'client_verify',
        verifiedAt: new Date().toISOString(),
    });
    await recordSubscriptionEvent(c.env.DB, {
        id: body.eventId ?? `apple_${transactionId}`,
        userId: user.id,
        provider: 'app_store',
        eventType: 'client_verify',
        externalSubscriptionId: payload.externalSubscriptionId,
        externalTransactionId: payload.externalTransactionId,
        productId,
        source: 'client_verify',
        rawEvent: body,
    });

    return c.json({ success: true });
});

router.post('/paddle/checkout', async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const body = await c.req.json().catch(() => ({}));
    const productId = body.productId ?? body.product_id;
    if (!productId) return c.json({ error: 'productId is required' }, 400);

    if (!c.env.PADDLE_API_KEY) {
        return c.json({ error: 'Paddle checkout is not configured' }, 503);
    }
    const priceId = paddlePriceId(c, productId);
    if (!priceId) {
        return c.json({ error: 'Paddle price is not configured for this product' }, 503);
    }

    const apiBase = c.env.ENVIRONMENT === 'production'
        ? 'https://api.paddle.com'
        : 'https://sandbox-api.paddle.com';
    const response = await fetch(`${apiBase}/transactions`, {
        method: 'POST',
        headers: {
            Authorization: `Bearer ${c.env.PADDLE_API_KEY}`,
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            items: [{ price_id: priceId, quantity: 1 }],
            collection_mode: 'automatic',
            custom_data: {
                user_id: user.id,
                product_id: productId,
            },
        }),
    });

    const data = await response.json().catch(() => null) as any;
    if (!response.ok) {
        return c.json({
            error: data?.error?.detail ?? data?.error?.message ?? 'Paddle checkout creation failed',
        }, response.status as any);
    }

    return c.json({
        checkout_url: data?.data?.checkout?.url ?? null,
        transaction_id: data?.data?.id ?? null,
    });
});

router.get('/paddle/cancel-link', async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const activeSubscription = await c.env.DB.prepare(`
        SELECT external_subscription_id
        FROM provider_subscriptions
        WHERE user_id = ?
          AND provider = 'paddle'
          AND status = 'active'
          AND (current_period_end IS NULL OR datetime(current_period_end) > CURRENT_TIMESTAMP)
        ORDER BY
          CASE WHEN current_period_end IS NULL THEN 1 ELSE 0 END DESC,
          datetime(current_period_end) DESC
        LIMIT 1
    `).bind(user.id).first<{ external_subscription_id: string }>();

    if (!activeSubscription?.external_subscription_id) {
        return c.json({ error: 'No active Paddle subscription found' }, 404);
    }

    if (!c.env.PADDLE_API_KEY) {
        return c.json({ error: 'Paddle subscription management is not configured' }, 503);
    }

    const apiBase = c.env.ENVIRONMENT === 'production'
        ? 'https://api.paddle.com'
        : 'https://sandbox-api.paddle.com';
    const response = await fetch(`${apiBase}/subscriptions/${activeSubscription.external_subscription_id}`, {
        method: 'GET',
        headers: {
            Authorization: `Bearer ${c.env.PADDLE_API_KEY}`,
            'Content-Type': 'application/json',
        },
    });

    const data = await response.json().catch(() => null) as any;
    if (!response.ok) {
        return c.json({
            error: data?.error?.detail ?? data?.error?.message ?? 'Failed to load Paddle subscription management link',
        }, response.status as any);
    }

    const cancelUrl = data?.data?.management_urls?.cancel ?? null;
    if (!cancelUrl) {
        return c.json({ error: 'Paddle cancellation link is unavailable' }, 502);
    }

    return c.json({
        cancel_url: cancelUrl,
    });
});

router.post('/paddle-webhook', async (c) => {
    try {
        const rawBody = await c.req.text();
        if (!isMockVerification(c)) {
            const valid = await verifyPaddleSignature(
                rawBody,
                c.req.header('Paddle-Signature'),
                c.env.PADDLE_WEBHOOK_SECRET,
            );
            if (!valid) return c.json({ error: 'Invalid Paddle signature' }, 401);
        }

        const body = JSON.parse(rawBody);
        const eventId = body.event_id ?? body.notification_id;
        const eventType = body.event_type;
        const data = body.data ?? {};
        const userId = data.custom_data?.user_id ?? data.custom_data?.aliolo_user_id;
        const subscriptionId = data.subscription_id ?? data.id;
        const productId =
            data.custom_data?.product_id ??
            data.items?.[0]?.price?.custom_data?.product_id ??
            data.items?.[0]?.price?.id ??
            null;

        if (!eventId || !eventType) return c.json({ error: 'Invalid Paddle event' }, 400);
        if (!userId || !subscriptionId) {
            return c.json({ success: true, ignored: true });
        }

        const inserted = await recordSubscriptionEvent(c.env.DB, {
            id: eventId,
            userId,
            provider: 'paddle',
            eventType,
            externalSubscriptionId: subscriptionId,
            externalTransactionId: data.transaction_id ?? data.id ?? null,
            productId,
            source: 'paddle_webhook',
            rawEvent: body,
        });
        if (!inserted) return c.json({ success: true, duplicate: true });

        const profile = await c.env.DB.prepare(
            'SELECT id FROM profiles WHERE id = ?'
        ).bind(userId).first();
        if (!profile) return c.json({ error: 'Aliolo user not found' }, 404);

        const status = ['subscription.canceled', 'subscription.paused'].includes(eventType)
            ? 'inactive'
            : 'active';
        const periodEnd = data.current_billing_period?.ends_at ?? data.billing_period?.ends_at ?? null;

        await upsertProviderSubscription(c.env.DB, {
            userId,
            provider: 'paddle',
            status,
            externalSubscriptionId: subscriptionId,
            externalCustomerId: data.customer_id ?? null,
            externalTransactionId: data.transaction_id ?? data.id ?? null,
            productId,
            environment: body.environment ?? null,
            periodStart: data.current_billing_period?.starts_at ?? data.billing_period?.starts_at ?? null,
            periodEnd,
            willRenew: status === 'active',
            rawPayload: body,
            lastVerificationSource: 'paddle_webhook',
            lastVerifiedAt: new Date().toISOString(),
        });

        await recomputeUserSubscription(c.env.DB, userId);
        return c.json({ success: true });
    } catch (e: any) {
        return c.json({ error: e.message }, 500);
    }
});

export default router;
