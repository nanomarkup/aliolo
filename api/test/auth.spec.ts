import { describe, it, expect } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';
import { signupUser } from './test-utils';

describe('Auth API', () => {
  const timestamp = Date.now();
  const testUser = {
    email: `test_${timestamp}@example.com`,
    password: 'password123',
    username: `testuser_${timestamp}`
  };

  it('should sign up a new user', async () => {
    const data = await signupUser(testUser);

    expect(data.user.email).toBe(testUser.email);
    expect(data.session_id).toBeDefined();
  });

  it('should sign up using invitation token', async () => {
    const inviteEmail = `invite_${Date.now()}@example.com`;
    const token = `token_${Date.now()}`;
    const expiresAt = Math.floor(Date.now() / 1000) + 3600;

    // 1. Create invitation
    await env.DB.prepare(
        "INSERT INTO invitations (token, email, inviter_id, expires_at) VALUES (?, ?, ?, ?)"
    ).bind(token, inviteEmail, 'system', expiresAt).run();

    // 2. Signup with invite
    const res = await app.request('/api/auth/signup-invite', {
      method: 'POST',
      body: JSON.stringify({
        email: inviteEmail,
        password: 'password123',
        username: 'invited_user',
        invite_token: token
      }),
      headers: { 'Content-Type': 'application/json' }
    }, env);

    if (res.status !== 200) {
        console.error('Invite Signup failed', await res.json());
    }
    expect(res.status).toBe(200);
    const data = await res.json() as any;
    expect(data.user.email).toBe(inviteEmail);
    expect(data.session_id).toBeDefined();

    // 3. Verify invitation is deleted
    const invite = await env.DB.prepare(
        "SELECT * FROM invitations WHERE token = ?"
    ).bind(token).first();
    expect(invite).toBeNull();
  });

  it('should login an existing user', async () => {
    const res = await app.request('/api/auth/login', {
      method: 'POST',
      body: JSON.stringify({
        email: testUser.email,
        password: testUser.password
      }),
      headers: { 'Content-Type': 'application/json' }
    }, env);

    expect(res.status).toBe(200);
    const data = await res.json() as any;
    expect(data.user.email).toBe(testUser.email);
    expect(data.session_id).toBeDefined();
  });

  it('should get current user profile', async () => {
    const loginRes = await app.request('/api/auth/login', {
      method: 'POST',
      body: JSON.stringify({
        email: testUser.email,
        password: testUser.password
      }),
      headers: { 'Content-Type': 'application/json' }
    }, env);
    const loginData = await loginRes.json() as any;

    const res = await app.request('/api/auth/me', {
      headers: { 'X-Session-Id': loginData.session_id }
    }, env);

    expect(res.status).toBe(200);
    const data = await res.json() as any;
    expect(data.user.email).toBe(testUser.email);
  });

  it('should logout', async () => {
    const loginRes = await app.request('/api/auth/login', {
      method: 'POST',
      body: JSON.stringify({
        email: testUser.email,
        password: testUser.password
      }),
      headers: { 'Content-Type': 'application/json' }
    }, env);
    const loginData = await loginRes.json() as any;

    const res = await app.request('/api/auth/logout', {
      method: 'POST',
      headers: { 'X-Session-Id': loginData.session_id }
    }, env);

    expect(res.status).toBe(200);
  });
});
