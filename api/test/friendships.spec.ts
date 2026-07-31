import { describe, it, expect, beforeAll } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';
import { signupUser } from './test-utils';

describe('Friendships API', () => {
  let user1: any;
  let user2: any;

  beforeAll(async () => {
    const timestamp = Date.now();
    
    user1 = await signupUser({ email: `f1_${timestamp}@test.com`, password: 'password123' });

    user2 = await signupUser({ email: `f2_${timestamp}@test.com`, password: 'password123', username: 'friend' });
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
