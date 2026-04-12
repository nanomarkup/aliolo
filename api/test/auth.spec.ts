import { describe, it, expect } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';

describe('Auth API', () => {
  const timestamp = Date.now();
  const testUser = {
    email: `test_${timestamp}@example.com`,
    password: 'password123',
    username: `testuser_${timestamp}`
  };

  it('should sign up a new user', async () => {
    const res = await app.request('/api/auth/signup', {
      method: 'POST',
      body: JSON.stringify(testUser),
      headers: { 'Content-Type': 'application/json' }
    }, env);

    if (res.status !== 200) {
        console.error('Signup failed', await res.json());
    }
    expect(res.status).toBe(200);
    const data = await res.json() as any;
    expect(data.user.email).toBe(testUser.email);
    expect(data.session_id).toBeDefined();
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
