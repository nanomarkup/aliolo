import { describe, it, expect, beforeAll } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';
import { signupUser } from './test-utils';

describe('Subscriptions API', () => {
  let sessionId: string;

  beforeAll(async () => {
    const timestamp = Date.now();
    const data = await signupUser({ email: `sub_${timestamp}@test.com`, password: 'password123' });
    sessionId = data.session_id;
  });

  it('should get subscription status (initially null or active after verify)', async () => {
    // 1. Initially might be null
    let res = await app.request('/api/subscriptions', {
      headers: { 'X-Session-Id': sessionId }
    }, env);
    expect(res.status).toBe(200);

    // 2. Verify subscription
    res = await app.request('/api/subscriptions/verify', {
      method: 'POST',
      body: JSON.stringify({ purchaseToken: 'test-token', productId: 'premium_year' }),
      headers: { 
        'Content-Type': 'application/json',
        'X-Session-Id': sessionId 
      }
    }, env);
    expect(res.status).toBe(200);

    // 3. Check status again
    res = await app.request('/api/subscriptions', {
      headers: { 'X-Session-Id': sessionId }
    }, env);
    expect(res.status).toBe(200);
    const data = await res.json() as any;
    expect(data.status).toBe('active');
  });
});
