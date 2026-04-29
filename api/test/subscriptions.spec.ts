import { describe, it, expect, beforeAll, vi } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';
import { signupUser } from './test-utils';
import { createSignedHeaders } from '../src/utils/google-play';

function base64FromBytes(bytes: Uint8Array): string {
  let binary = '';
  for (const finalByte of bytes) {
    binary += String.fromCharCode(finalByte);
  }
  return btoa(binary);
}

function toPem(pkcs8: ArrayBuffer): string {
  const base64 = base64FromBytes(new Uint8Array(pkcs8));
  const lines = base64.match(/.{1,64}/g) ?? [];
  return `-----BEGIN PRIVATE KEY-----\n${lines.join('\n')}\n-----END PRIVATE KEY-----`;
}

async function buildTestServiceAccountJson() {
  const keyPair = await crypto.subtle.generateKey(
    {
      name: 'RSASSA-PKCS1-v1_5',
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: 'SHA-256',
    },
    true,
    ['sign', 'verify'],
  );
  const pkcs8 = await crypto.subtle.exportKey('pkcs8', keyPair.privateKey);
  return JSON.stringify({
    client_email: 'aliolo-subscriptions@test.iam.gserviceaccount.com',
    private_key: toPem(pkcs8),
    private_key_id: 'test-private-key-id',
    token_uri: 'https://oauth2.googleapis.com/token',
  });
}

describe('Subscriptions API', () => {
  let sessionId: string;
  let userId: string;

  beforeAll(async () => {
    const timestamp = Date.now();
    const data = await signupUser({ email: `sub_${timestamp}@test.com`, password: 'password123' });
    sessionId = data.session_id;
    userId = data.user.id;
    (env as any).ENVIRONMENT = 'test';
  });

  it('should get inactive subscription status initially', async () => {
    const res = await app.request('/api/subscriptions', {
      headers: { 'X-Session-Id': sessionId }
    }, env);
    expect(res.status).toBe(200);
    const data = await res.json() as any;
    expect(data.status).toBe('inactive');
    expect(data.effective_source).toBe('none');
  });

  it('should verify a Google Play subscription through the Android Publisher API path', async () => {
    const originalFetch = globalThis.fetch;
    const originalServiceAccount = (env as any).GOOGLE_PLAY_SERVICE_ACCOUNT_JSON;
    const originalPackageName = (env as any).GOOGLE_PLAY_PACKAGE_NAME;
    (env as any).GOOGLE_PLAY_SERVICE_ACCOUNT_JSON = await buildTestServiceAccountJson();
    (env as any).GOOGLE_PLAY_PACKAGE_NAME = 'com.nanomarkup.aliolo';

    (globalThis as any).fetch = vi.fn(async (input: RequestInfo | URL) => {
      const url = typeof input === 'string' ? input : input instanceof URL ? input.toString() : input.url;
      if (url === 'https://oauth2.googleapis.com/token') {
        return new Response(JSON.stringify({ access_token: 'google-access-token' }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      if (url.includes('/purchases/subscriptionsv2/tokens/google-token-1')) {
        return new Response(JSON.stringify({
          startTime: new Date(Date.now() - 60 * 60 * 1000).toISOString(),
          subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
          acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
          lineItems: [
            {
              productId: 'aliolo_premium_monthly',
              expiryTime: new Date(Date.now() + 31 * 24 * 60 * 60 * 1000).toISOString(),
              latestSuccessfulOrderId: 'GPA.1',
              autoRenewingPlan: {
                autoRenewEnabled: true,
              },
            },
          ],
        }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      throw new Error(`Unexpected fetch in subscriptions test: ${url}`);
    }) as any;

    try {
      const res = await app.request('/api/subscriptions/google/verify', {
        method: 'POST',
        body: JSON.stringify({
          purchaseToken: 'google-token-1',
          productId: 'aliolo_premium_monthly',
          orderId: 'GPA.1',
          packageName: 'com.nanomarkup.aliolo',
        }),
        headers: {
          'Content-Type': 'application/json',
          'X-Session-Id': sessionId
        }
      }, env);
      expect(res.status).toBe(200);

      const status = await app.request('/api/subscriptions', {
        headers: { 'X-Session-Id': sessionId }
      }, env);
      const data = await status.json() as any;
      expect(data.status).toBe('active');
      expect(data.effective_source).toBe('provider');
      expect(data.provider).toBe('google_play');
      expect(data.product_id).toBe('aliolo_premium_monthly');
    } finally {
      (globalThis as any).fetch = originalFetch;
      (env as any).GOOGLE_PLAY_SERVICE_ACCOUNT_JSON = originalServiceAccount;
      (env as any).GOOGLE_PLAY_PACKAGE_NAME = originalPackageName;
    }
  });

  it('should create a pending Google Play purchase intent before checkout', async () => {
    const res = await app.request('/api/subscriptions/google/purchase-intent', {
      method: 'POST',
      body: JSON.stringify({
        productId: 'aliolo_premium_weekly',
        packageName: 'com.nanomarkup.aliolo',
        googleObfuscatedAccountId: 'google-user-pending-1',
      }),
      headers: {
        'Content-Type': 'application/json',
        'X-Session-Id': sessionId,
      },
    }, env);
    expect(res.status).toBe(200);

    const pending = await env.DB.prepare(`
      SELECT product_id, google_obfuscated_account_id, status
      FROM pending_purchase_intents
      WHERE user_id = ?
      ORDER BY datetime(created_at) DESC
      LIMIT 1
    `).bind(userId).first() as any;
    expect(pending.product_id).toBe('aliolo_premium_weekly');
    expect(pending.google_obfuscated_account_id).toBe('google-user-pending-1');
    expect(pending.status).toBe('pending');
  });

  it('should reuse the same pending Google Play purchase intent for repeated attempts', async () => {
    const firstPending = await env.DB.prepare(`
      SELECT id, product_id, updated_at
      FROM pending_purchase_intents
      WHERE user_id = ?
        AND provider = 'google_play'
        AND status = 'pending'
      ORDER BY datetime(created_at) DESC
      LIMIT 1
    `).bind(userId).first() as any;
    expect(firstPending?.id).toBeTruthy();

    const res = await app.request('/api/subscriptions/google/purchase-intent', {
      method: 'POST',
      body: JSON.stringify({
        productId: 'aliolo_premium_monthly',
        packageName: 'com.nanomarkup.aliolo',
        googleObfuscatedAccountId: 'google-user-pending-1',
      }),
      headers: {
        'Content-Type': 'application/json',
        'X-Session-Id': sessionId,
      },
    }, env);
    expect(res.status).toBe(200);

    const rows = await env.DB.prepare(`
      SELECT id, product_id, google_obfuscated_account_id, status
      FROM pending_purchase_intents
      WHERE user_id = ?
        AND provider = 'google_play'
        AND status = 'pending'
      ORDER BY datetime(created_at) DESC
    `).bind(userId).all<any>();

    expect(rows.results).toHaveLength(1);
    expect(rows.results[0].id).toBe(firstPending.id);
    expect(rows.results[0].product_id).toBe('aliolo_premium_monthly');
    expect(rows.results[0].google_obfuscated_account_id).toBe('google-user-pending-1');
    expect(rows.results[0].status).toBe('pending');
  });

  it('should let a manual grant extend access without changing provider records', async () => {
    const manualGrantId = 'manual-sub-test-1';
    await env.DB.prepare(`
      INSERT INTO manual_subscription_grants (
        id,
        user_id,
        status,
        reason,
        starts_at,
        ends_at,
        created_at,
        updated_at
      ) VALUES (?, ?, 'active', 'Test extension', CURRENT_TIMESTAMP, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    `).bind(
      manualGrantId,
      userId,
      new Date(Date.now() + 90 * 24 * 60 * 60 * 1000).toISOString(),
    ).run();

    const status = await app.request('/api/subscriptions', {
      headers: { 'X-Session-Id': sessionId }
    }, env);
    const data = await status.json() as any;
    expect(data.status).toBe('active');
    expect(data.effective_source).toBe('manual');
    expect(data.provider).toBe('aliolo_manual');
    expect(data.active_provider_subscription_id).toBeTruthy();
    expect(data.active_manual_grant_id).toBe(manualGrantId);

    const provider = await env.DB.prepare(`
      SELECT provider, status, product_id
      FROM provider_subscriptions
      WHERE user_id = ?
    `).bind(userId).first() as any;
    expect(provider.provider).toBe('google_play');
    expect(provider.status).toBe('active');
    expect(provider.product_id).toBe('aliolo_premium_monthly');
  });

  it('should ingest a signed Google Play webhook update', async () => {
    (env as any).GOOGLE_PLAY_VERIFIER_SHARED_SECRET = 'test-google-secret';
    await env.DB.prepare(`
      INSERT INTO provider_subscriptions (
        id,
        user_id,
        provider,
        status,
        external_subscription_id,
        external_customer_id,
        purchase_token,
        product_id,
        google_obfuscated_account_id,
        created_at,
        updated_at
      ) VALUES (?, ?, 'google_play', 'inactive', ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    `).bind(
      'google_webhook_seed',
      userId,
      'google-webhook-token',
      'google-user-1',
      'google-webhook-token',
      'aliolo_premium_monthly',
      'google-user-1',
    ).run();

    const body = JSON.stringify({
      eventId: 'google_rtdn_event_1',
      eventType: 'rtdn_subscription_4',
      source: 'rtdn',
      googleObfuscatedAccountId: 'google-user-1',
      verification: {
        packageName: 'com.nanomarkup.aliolo',
        purchaseToken: 'google-webhook-token',
        productId: 'aliolo_premium_monthly',
        status: 'active',
        subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
        periodStart: new Date(Date.now() - 60 * 60 * 1000).toISOString(),
        periodEnd: new Date(Date.now() + 31 * 24 * 60 * 60 * 1000).toISOString(),
        willRenew: true,
        environment: 'production',
        externalSubscriptionId: 'google-webhook-token',
        externalCustomerId: 'google-user-1',
        externalTransactionId: 'GPA.webhook.1',
        rawPayload: {
          subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
        },
      },
    });
    const signedHeaders = await createSignedHeaders('test-google-secret', body);

    const res = await app.request('/api/subscriptions/google/webhook', {
      method: 'POST',
      body,
      headers: signedHeaders,
    }, env);
    expect(res.status).toBe(200);

    const status = await app.request('/api/subscriptions', {
      headers: { 'X-Session-Id': sessionId }
    }, env);
    const data = await status.json() as any;
    expect(data.status).toBe('active');

    const event = await env.DB.prepare(`
      SELECT source, event_type
      FROM subscription_events
      WHERE id = ?
    `).bind('google_rtdn_event_1').first() as any;
    expect(event.source).toBe('rtdn');
    expect(event.event_type).toBe('rtdn_subscription_4');
  });

  it('should claim a restored Google Play purchase for the signed-in user', async () => {
    const originalFetch = globalThis.fetch;
    const originalServiceAccount = (env as any).GOOGLE_PLAY_SERVICE_ACCOUNT_JSON;
    const originalPackageName = (env as any).GOOGLE_PLAY_PACKAGE_NAME;
    (env as any).GOOGLE_PLAY_SERVICE_ACCOUNT_JSON = await buildTestServiceAccountJson();
    (env as any).GOOGLE_PLAY_PACKAGE_NAME = 'com.nanomarkup.aliolo';

    (globalThis as any).fetch = vi.fn(async (input: RequestInfo | URL) => {
      const url = typeof input === 'string' ? input : input instanceof URL ? input.toString() : input.url;
      if (url === 'https://oauth2.googleapis.com/token') {
        return new Response(JSON.stringify({ access_token: 'google-access-token' }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      if (url.includes('/purchases/subscriptionsv2/tokens/google-restore-token-1')) {
        return new Response(JSON.stringify({
          startTime: new Date(Date.now() - 60 * 60 * 1000).toISOString(),
          subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
          acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
          externalAccountIdentifiers: {
            obfuscatedExternalAccountId: 'google-user-pending-1',
          },
          lineItems: [
            {
              productId: 'aliolo_premium_weekly',
              expiryTime: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
              latestSuccessfulOrderId: 'GPA.restore.1',
              autoRenewingPlan: {
                autoRenewEnabled: false,
              },
            },
          ],
        }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      throw new Error(`Unexpected fetch in restore claim test: ${url}`);
    }) as any;

    try {
      const res = await app.request('/api/subscriptions/google/claim-restored', {
        method: 'POST',
        body: JSON.stringify({
          purchaseToken: 'google-restore-token-1',
          productId: 'aliolo_premium_weekly',
          packageName: 'com.nanomarkup.aliolo',
          googleObfuscatedAccountId: 'google-user-pending-1',
        }),
        headers: {
          'Content-Type': 'application/json',
          'X-Session-Id': sessionId,
        },
      }, env);
      expect(res.status).toBe(200);

      const provider = await env.DB.prepare(`
        SELECT status, product_id, last_verification_source
        FROM provider_subscriptions
        WHERE user_id = ? AND purchase_token = ?
      `).bind(userId, 'google-restore-token-1').first() as any;
      expect(provider.status).toBe('active');
      expect(provider.product_id).toBe('aliolo_premium_weekly');
      expect(provider.last_verification_source).toBe('reconcile');

      const event = await env.DB.prepare(`
        SELECT source, event_type
        FROM subscription_events
        WHERE user_id = ? AND external_subscription_id = ?
        ORDER BY datetime(created_at) DESC
        LIMIT 1
      `).bind(userId, 'google-restore-token-1').first() as any;
      expect(event.source).toBe('reconcile');
      expect(event.event_type).toBe('restore_claim');
    } finally {
      (globalThis as any).fetch = originalFetch;
      (env as any).GOOGLE_PLAY_SERVICE_ACCOUNT_JSON = originalServiceAccount;
      (env as any).GOOGLE_PLAY_PACKAGE_NAME = originalPackageName;
    }
  });

  it('should return signed Google Play reconcile candidates', async () => {
    (env as any).GOOGLE_PLAY_VERIFIER_SHARED_SECRET = 'test-google-secret';
    const signedHeaders = await createSignedHeaders('test-google-secret', '');
    const res = await app.request('/api/subscriptions/google/reconcile-candidates?limit=10', {
      method: 'GET',
      headers: signedHeaders,
    }, env);
    expect(res.status).toBe(200);

    const data = await res.json() as any;
    expect(Array.isArray(data.subscriptions)).toBe(true);
    expect(data.subscriptions.some((candidate: any) => candidate.purchaseToken === 'google-webhook-token')).toBe(true);
  });

  it('should activate web access from a Paddle subscription webhook', async () => {
    const webUser = await signupUser({
      email: `sub_web_${Date.now()}@test.com`,
      password: 'password123',
    });

    const res = await app.request('/api/subscriptions/paddle-webhook', {
      method: 'POST',
      body: JSON.stringify({
        event_id: 'evt_paddle_1',
        event_type: 'subscription.activated',
        data: {
          id: 'sub_paddle_1',
          customer_id: 'ctm_1',
          custom_data: {
            user_id: webUser.user.id,
            product_id: 'aliolo_premium_yearly',
          },
          current_billing_period: {
            starts_at: new Date().toISOString(),
            ends_at: new Date(Date.now() + 366 * 24 * 60 * 60 * 1000).toISOString(),
          },
        },
      }),
      headers: { 'Content-Type': 'application/json' }
    }, env);
    expect(res.status).toBe(200);

    const status = await app.request('/api/subscriptions', {
      headers: { 'X-Session-Id': webUser.session_id }
    }, env);
    const data = await status.json() as any;
    expect(data.status).toBe('active');
    expect(data.effective_source).toBe('provider');
    expect(data.provider).toBe('paddle');
    expect(data.billing_provider).toBe('paddle');
    expect(data.product_id).toBe('aliolo_premium_yearly');
  });

  it('should ignore duplicate Paddle events', async () => {
    const payload = {
      event_id: 'evt_paddle_duplicate',
      event_type: 'subscription.activated',
      data: {
        id: 'sub_paddle_duplicate',
        custom_data: { user_id: userId, product_id: 'aliolo_premium_weekly' },
      },
    };

    let res = await app.request('/api/subscriptions/paddle-webhook', {
      method: 'POST',
      body: JSON.stringify(payload),
      headers: { 'Content-Type': 'application/json' }
    }, env);
    expect(res.status).toBe(200);

    res = await app.request('/api/subscriptions/paddle-webhook', {
      method: 'POST',
      body: JSON.stringify(payload),
      headers: { 'Content-Type': 'application/json' }
    }, env);
    expect(res.status).toBe(200);
    expect((await res.json() as any).duplicate).toBe(true);
  });

  it('should return a Paddle cancellation link for an active web subscription', async () => {
    const webUser = await signupUser({
      email: `sub_web_cancel_${Date.now()}@test.com`,
      password: 'password123',
    });

    const activate = await app.request('/api/subscriptions/paddle-webhook', {
      method: 'POST',
      body: JSON.stringify({
        event_id: 'evt_paddle_cancel_link',
        event_type: 'subscription.activated',
        data: {
          id: 'sub_paddle_cancel_link',
          customer_id: 'ctm_cancel_link',
          custom_data: {
            user_id: webUser.user.id,
            product_id: 'aliolo_premium_monthly',
          },
          current_billing_period: {
            starts_at: new Date().toISOString(),
            ends_at: new Date(Date.now() + 31 * 24 * 60 * 60 * 1000).toISOString(),
          },
        },
      }),
      headers: { 'Content-Type': 'application/json' }
    }, env);
    expect(activate.status).toBe(200);

    const originalFetch = globalThis.fetch;
    (env as any).PADDLE_API_KEY = 'test-paddle-key';
    (globalThis as any).fetch = vi.fn(async () => new Response(JSON.stringify({
      data: {
        management_urls: {
          cancel: 'https://buyer-portal.paddle.com/subscriptions/sub_paddle_cancel_link/cancel',
        },
      },
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })) as any;

    try {
      const res = await app.request('/api/subscriptions/paddle/cancel-link', {
        headers: { 'X-Session-Id': webUser.session_id },
      }, env);

      expect(res.status).toBe(200);
      const data = await res.json() as any;
      expect(data.cancel_url).toContain('/cancel');
    } finally {
      (globalThis as any).fetch = originalFetch;
    }
  });
});
