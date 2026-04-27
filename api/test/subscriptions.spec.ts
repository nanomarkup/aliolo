import { describe, it, expect, beforeAll } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';
import { signupUser } from './test-utils';

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

  it('should store a Google Play provider subscription in test verification mode', async () => {
    const res = await app.request('/api/subscriptions/google/verify', {
      method: 'POST',
      body: JSON.stringify({
        purchaseToken: 'google-token-1',
        productId: 'aliolo_premium_monthly',
        orderId: 'GPA.1',
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
});
