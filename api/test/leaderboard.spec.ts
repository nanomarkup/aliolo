import { describe, it, expect, beforeAll } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';

describe('Leaderboard API', () => {
  let sessionId: string;

  beforeAll(async () => {
    const timestamp = Date.now();
    const res = await app.request('/api/auth/signup', {
      method: 'POST',
      body: JSON.stringify({ email: `leader_${timestamp}@test.com`, password: 'password123' }),
      headers: { 'Content-Type': 'application/json' }
    }, env);
    const data = await res.json() as any;
    sessionId = data.session_id;
  });

  it('should get global leaderboard', async () => {
    const res = await app.request('/api/leaderboard', {
      headers: { 'X-Session-Id': sessionId }
    }, env);

    expect(res.status).toBe(200);
    const data = await res.json() as any[];
    expect(Array.isArray(data)).toBe(true);
  });

  it('should get user rank', async () => {
    const res = await app.request('/api/leaderboard/rank', {
      headers: { 'X-Session-Id': sessionId }
    }, env);

    expect(res.status).toBe(200);
    const data = await res.json() as any;
    expect(data).toHaveProperty('rank');
  });
});
