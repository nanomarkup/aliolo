import { OpenAPIHono } from '@hono/zod-openapi';
import { generateId } from 'lucia';
import type { AppEnv } from '../types';
import {
    recomputeUserSubscription,
    recordSubscriptionEvent,
    type ProviderName,
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
        productId,
        externalSubscriptionId,
        externalCustomerId: body.customerId ?? body.customer_id ?? null,
        externalTransactionId,
        purchaseToken,
        environment: body.environment ?? null,
        periodStart: body.currentPeriodStart ?? body.current_period_start ?? null,
        periodEnd,
        willRenew: body.willRenew ?? body.will_renew ?? null,
    };
}

async function upsertProviderSubscription(
    db: D1Database,
    userId: string,
    payload: ReturnType<typeof providerPayload>,
    rawPayload: unknown,
) {
    await db.prepare(`
        INSERT INTO provider_subscriptions (
            id,
            user_id,
            provider,
            status,
            external_subscription_id,
            external_customer_id,
            external_transaction_id,
            purchase_token,
            product_id,
            environment,
            current_period_start,
            current_period_end,
            will_renew,
            raw_payload,
            created_at,
            updated_at
        ) VALUES (?, ?, ?, 'active', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON CONFLICT(provider, external_subscription_id) DO UPDATE SET
            user_id = excluded.user_id,
            status = excluded.status,
            external_customer_id = excluded.external_customer_id,
            external_transaction_id = excluded.external_transaction_id,
            purchase_token = excluded.purchase_token,
            product_id = excluded.product_id,
            environment = excluded.environment,
            current_period_start = excluded.current_period_start,
            current_period_end = excluded.current_period_end,
            will_renew = excluded.will_renew,
            raw_payload = excluded.raw_payload,
            updated_at = CURRENT_TIMESTAMP
    `).bind(
        generateId(15),
        userId,
        payload.provider,
        payload.externalSubscriptionId,
        payload.externalCustomerId,
        payload.externalTransactionId,
        payload.purchaseToken,
        payload.productId,
        payload.environment,
        payload.periodStart,
        payload.periodEnd,
        payload.willRenew == null ? null : payload.willRenew ? 1 : 0,
        JSON.stringify(rawPayload),
    ).run();

    await recomputeUserSubscription(db, userId);
}

function isMockVerification(c: any): boolean {
    return c.env.SUBSCRIPTION_VERIFICATION_MODE === 'mock' || c.env.ENVIRONMENT === 'test';
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

router.post('/google/verify', async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const body = await c.req.json().catch(() => ({}));
    const token = body.purchaseToken ?? body.purchase_token;
    const productId = body.productId ?? body.product_id;
    if (!token || !productId) {
        return c.json({ error: 'purchaseToken and productId are required' }, 400);
    }

    if (!isMockVerification(c)) {
        return c.json({ error: 'Google Play verification is not configured' }, 503);
    }

    const payload = providerPayload(body, 'google_play');
    await upsertProviderSubscription(c.env.DB, user.id, payload, body);
    await recordSubscriptionEvent(c.env.DB, {
        id: body.eventId ?? `google_${token}`,
        userId: user.id,
        provider: 'google_play',
        eventType: 'client_verify',
        externalSubscriptionId: payload.externalSubscriptionId,
        externalTransactionId: payload.externalTransactionId,
        productId,
        rawEvent: body,
    });

    return c.json({ success: true });
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
    await upsertProviderSubscription(c.env.DB, user.id, payload, body);
    await recordSubscriptionEvent(c.env.DB, {
        id: body.eventId ?? `apple_${transactionId}`,
        userId: user.id,
        provider: 'app_store',
        eventType: 'client_verify',
        externalSubscriptionId: payload.externalSubscriptionId,
        externalTransactionId: payload.externalTransactionId,
        productId,
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

        await c.env.DB.prepare(`
            INSERT INTO provider_subscriptions (
                id,
                user_id,
                provider,
                status,
                external_subscription_id,
                external_customer_id,
                external_transaction_id,
                product_id,
                environment,
                current_period_start,
                current_period_end,
                will_renew,
                raw_payload,
                created_at,
                updated_at
            ) VALUES (?, ?, 'paddle', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            ON CONFLICT(provider, external_subscription_id) DO UPDATE SET
                user_id = excluded.user_id,
                status = excluded.status,
                external_customer_id = excluded.external_customer_id,
                external_transaction_id = excluded.external_transaction_id,
                product_id = excluded.product_id,
                environment = excluded.environment,
                current_period_start = excluded.current_period_start,
                current_period_end = excluded.current_period_end,
                will_renew = excluded.will_renew,
                raw_payload = excluded.raw_payload,
                updated_at = CURRENT_TIMESTAMP
        `).bind(
            generateId(15),
            userId,
            status,
            subscriptionId,
            data.customer_id ?? null,
            data.transaction_id ?? data.id ?? null,
            productId,
            body.environment ?? null,
            data.current_billing_period?.starts_at ?? data.billing_period?.starts_at ?? null,
            periodEnd,
            status === 'active' ? 1 : 0,
            JSON.stringify(body),
        ).run();

        await recomputeUserSubscription(c.env.DB, userId);
        return c.json({ success: true });
    } catch (e: any) {
        return c.json({ error: e.message }, 500);
    }
});

export default router;
