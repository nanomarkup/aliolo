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

    const profile: any = await env.DB.prepare(
      'SELECT last_active_date FROM profiles WHERE email = ?'
    ).bind(testUser.email).first();
    expect(profile.last_active_date).toBeTruthy();
  });

  it('links first-run onboarding and assigns official starter subjects on signup', async () => {
    const suffix = Date.now();
    const officialUserId = `official_${suffix}`;
    const onboardingSessionId = `onboarding_${suffix}`;

    await env.DB.prepare(
      "INSERT INTO profiles (id, email, username) VALUES (?, 'aliolo@nohainc.com', 'Aliolo') ON CONFLICT(email) DO NOTHING"
    ).bind(officialUserId).run();
    const official: any = await env.DB.prepare(
      "SELECT id FROM profiles WHERE email = 'aliolo@nohainc.com'"
    ).first();

    for (let i = 0; i < 3; i++) {
      await env.DB.prepare(`
        INSERT INTO subjects (id, pillar_id, owner_id, is_public, age_group, name)
        VALUES (?, 6, ?, 1, 'advanced', ?)
      `).bind(`starter_${suffix}_${i}`, official.id, `Starter ${i}`).run();
    }
    await env.DB.prepare(`
      INSERT INTO subjects (id, pillar_id, owner_id, is_public, age_group, name)
      VALUES (?, 6, ?, 0, 'advanced', 'Private Starter')
    `).bind(`private_${suffix}`, official.id).run();
    await env.DB.prepare(`
      INSERT INTO onboarding_analytics (session_id, age_range, pillar_id)
      VALUES (?, 'age_19_25', 6)
    `).bind(onboardingSessionId).run();

    const data = await signupUser({
      email: `onboarding_${suffix}@example.com`,
      password: 'password123',
      username: `onboarding_${suffix}`,
      onboarding_session_id: onboardingSessionId,
    });

    const analytics: any = await env.DB.prepare(
      'SELECT user_email, age_range, pillar_id FROM onboarding_analytics WHERE session_id = ?'
    ).bind(onboardingSessionId).first();
    expect(analytics.user_email).toBe(data.user.email);
    expect(analytics.age_range).toBe('age_19_25');
    expect(analytics.pillar_id).toBe(6);

    const profile: any = await env.DB.prepare(
      'SELECT main_pillar_id, last_source_filter FROM profiles WHERE id = ?'
    ).bind(data.user.id).first();
    expect(profile.main_pillar_id).toBe(6);
    expect(profile.last_source_filter).toBe('public');

    const { results } = await env.DB.prepare(
      'SELECT subject_id FROM user_subjects WHERE user_id = ? ORDER BY subject_id'
    ).bind(data.user.id).all();
    expect(results.map((row: any) => row.subject_id)).toEqual([
      `starter_${suffix}_0`,
      `starter_${suffix}_1`,
      `starter_${suffix}_2`,
    ]);
  });

  it('backfills missing onboarding analytics from signup payload', async () => {
    const suffix = Date.now();
    const officialUserId = `official_backfill_${suffix}`;
    const onboardingSessionId = `missing_onboarding_${suffix}`;

    await env.DB.prepare(
      "INSERT INTO profiles (id, email, username) VALUES (?, 'aliolo@nohainc.com', 'Aliolo') ON CONFLICT(email) DO NOTHING"
    ).bind(officialUserId).run();
    const official: any = await env.DB.prepare(
      "SELECT id FROM profiles WHERE email = 'aliolo@nohainc.com'"
    ).first();

    for (let i = 0; i < 3; i++) {
      await env.DB.prepare(`
        INSERT INTO subjects (id, pillar_id, owner_id, is_public, age_group, name)
        VALUES (?, 6, ?, 1, 'advanced', ?)
      `).bind(`backfill_starter_${suffix}_${i}`, official.id, `Backfill Starter ${i}`).run();
    }

    const data = await signupUser({
      email: `backfill_${suffix}@example.com`,
      password: 'password123',
      username: `backfill_${suffix}`,
      onboarding_session_id: onboardingSessionId,
      onboarding_age_range: 'age_26_35',
      onboarding_pillar_id: 6,
    });

    const analytics: any = await env.DB.prepare(
      'SELECT user_email, age_range, pillar_id FROM onboarding_analytics WHERE session_id = ?'
    ).bind(onboardingSessionId).first();
    expect(analytics.user_email).toBe(data.user.email);
    expect(analytics.age_range).toBe('age_26_35');
    expect(analytics.pillar_id).toBe(6);
  });

  it('deletes onboarding analytics for the account email on account deletion', async () => {
    const suffix = Date.now();
    const onboardingSessionId = `delete_onboarding_${suffix}`;
    const email = `delete_${suffix}@example.com`;

    await env.DB.prepare(`
      INSERT INTO onboarding_analytics (session_id, user_email, age_range, pillar_id)
      VALUES (?, ?, 'age_19_25', 6)
    `).bind(onboardingSessionId, email).run();

    const signupData = await signupUser({
      email,
      password: 'password123',
      username: `delete_${suffix}`,
      onboarding_session_id: onboardingSessionId,
    });

    const deleteRes = await app.request('/api/auth/delete', {
      method: 'POST',
      body: JSON.stringify({ password: 'password123' }),
      headers: {
        'Content-Type': 'application/json',
        'X-Session-Id': signupData.session_id,
      },
    }, env);

    expect(deleteRes.status).toBe(200);

    const analytics: any = await env.DB.prepare(
      'SELECT session_id FROM onboarding_analytics WHERE user_email = ?'
    ).bind(email).first();
    expect(analytics).toBeNull();
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

  it('should persist media auto-play mute preference', async () => {
    const loginRes = await app.request('/api/auth/login', {
      method: 'POST',
      body: JSON.stringify({
        email: testUser.email,
        password: testUser.password
      }),
      headers: { 'Content-Type': 'application/json' }
    }, env);
    const loginData = await loginRes.json() as any;

    const updateRes = await app.request('/api/auth/update', {
      method: 'POST',
      body: JSON.stringify({
        media_auto_play_muted: true,
      }),
      headers: {
        'Content-Type': 'application/json',
        'X-Session-Id': loginData.session_id,
      }
    }, env);

    expect(updateRes.status).toBe(200);

    const meRes = await app.request('/api/auth/me', {
      headers: { 'X-Session-Id': loginData.session_id }
    }, env);

    expect(meRes.status).toBe(200);
    const meData = await meRes.json() as any;
    expect(meData.user.media_auto_play_muted).toBe(1);
  });
});
