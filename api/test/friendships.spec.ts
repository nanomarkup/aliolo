import { describe, it, expect, beforeAll } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';

describe('Friendships API', () => {
  let user1: any;
  let user2: any;

  beforeAll(async () => {
    const timestamp = Date.now();
    
    const res1 = await app.request('/api/auth/signup', {
      method: 'POST',
      body: JSON.stringify({ email: `f1_${timestamp}@test.com`, password: 'password123' }),
      headers: { 'Content-Type': 'application/json' }
    }, env);
    user1 = await res1.json();

    const res2 = await app.request('/api/auth/signup', {
      method: 'POST',
      body: JSON.stringify({ email: `f2_${timestamp}@test.com`, password: 'password123', username: 'friend' }),
      headers: { 'Content-Type': 'application/json' }
    }, env);
    user2 = await res2.json();
  });

  it('should send a friend request', async () => {
    const res = await app.request('/api/friendships/request', {
      method: 'POST',
      body: JSON.stringify({ email: user2.user.email }),
      headers: { 
        'Content-Type': 'application/json',
        'X-Session-Id': user1.session_id
      }
    }, env);

    if (res.status !== 200) {
        console.error('Friend request failed:', await res.json());
    }
    expect(res.status).toBe(200);
  });

  it('should list friends', async () => {
    const res = await app.request('/api/friendships', {
      headers: { 'X-Session-Id': user1.session_id }
    }, env);

    expect(res.status).toBe(200);
    const data = await res.json() as any[];
    expect(Array.isArray(data)).toBe(true);
  });
});
