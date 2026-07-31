import { describe, it, expect, beforeAll } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';
import { signupUser } from './test-utils';

describe('Admin Users API', () => {
  const adminUserId = 'usyeo7d2yzf2773';
  const adminSessionId = 'admin-session';
  const premiumSessionId = 'premium-session';
  const normalSessionId = 'normal-session';
  let premiumUserId = '';
  let usageSubjectId = '';
  let onboardingRecentEmail = '';
  let onboardingSecondaryEmail = '';

  beforeAll(async () => {
    await env.DB.prepare(`
      INSERT OR REPLACE INTO profiles (
        id,
        username,
        email,
        total_xp,
        current_streak,
        max_streak,
        theme_mode,
        ui_language,
        default_language,
        daily_goal_count,
        next_daily_goal,
        daily_completions,
        sidebar_left,
        sound_enabled,
        auto_play_enabled,
        show_on_leaderboard,
        show_documentation,
        learn_session_size,
        test_session_size,
        learn_autoplay_delay_seconds,
        options_count,
        main_pillar_id,
        is_premium
      ) VALUES (?, 'Admin User', 'admin@example.com', 12, 2, 5, 'system', 'en', 'en', 20, 20, 0, 0, 1, 0, 1, 1, 10, 10, 3, 6, 6, 1)
    `).bind(adminUserId).run();

    await env.DB.prepare(`
      INSERT OR REPLACE INTO sessions (id, user_id, expires_at)
      VALUES (?, ?, ?)
    `).bind(adminSessionId, adminUserId, Date.now() + 86_400_000).run();

    const normal = await signupUser({
      email: `admin_normal_${Date.now()}@test.com`,
      password: 'password123',
    });
    await env.DB.prepare(`
      INSERT OR REPLACE INTO sessions (id, user_id, expires_at)
      VALUES (?, ?, ?)
    `).bind(normalSessionId, normal.user.id, Date.now() + 86_400_000).run();

    const premium = await signupUser({
      email: `admin_premium_${Date.now()}@test.com`,
      password: 'password123',
      username: 'PremiumUser',
    });
    premiumUserId = premium.user.id;
    await env.DB.prepare(`
      INSERT OR REPLACE INTO sessions (id, user_id, expires_at)
      VALUES (?, ?, ?)
    `).bind(premiumSessionId, premium.user.id, Date.now() + 86_400_000).run();
    await env.DB.prepare(`
      INSERT OR REPLACE INTO manual_subscription_grants (
        id,
        user_id,
        status,
        reason,
        starts_at,
        ends_at,
        created_at,
        updated_at
      ) VALUES (?, ?, 'active', 'Test premium user', CURRENT_TIMESTAMP, DATE(CURRENT_TIMESTAMP, '+1 year'), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    `).bind('manual-premium-user', premium.user.id).run();

    usageSubjectId = `admin-usage-subject-${Date.now()}`;
    await env.DB.prepare("INSERT OR IGNORE INTO pillars (id, sort_order, name) VALUES (1, 1, 'Core')").run();
    await env.DB.prepare(
      "INSERT INTO subjects (id, pillar_id, owner_id, name) VALUES (?, 1, ?, 'Admin Usage Subject')"
    ).bind(usageSubjectId, adminUserId).run();
    await env.DB.prepare(`
      INSERT INTO subject_usage_stats (
        subject_id,
        mode,
        started_count,
        completed_count,
        updated_at
      ) VALUES (?, 'learn', 4, 3, CURRENT_TIMESTAMP), (?, 'test', 2, 1, CURRENT_TIMESTAMP)
    `).bind(usageSubjectId, usageSubjectId).run();

    onboardingRecentEmail = `oa_recent_${Date.now()}@test.com`;
    onboardingSecondaryEmail = `oa_secondary_${Date.now()}@test.com`;

    await env.DB.prepare(`
      INSERT OR REPLACE INTO pillars (id, sort_order, name)
      VALUES (6, 6, 'Academic & Professional'), (7, 7, 'Arts & Creativity')
    `).run();

    await env.DB.prepare(`
      INSERT OR REPLACE INTO onboarding_analytics (
        session_id,
        user_email,
        age_range,
        pillar_id,
        last_slide_index,
        created_at,
        updated_at
      ) VALUES
        (?, ?, 'age_15_18', 6, 6, ?, ?),
        (?, ?, 'age_19_25', 7, 2, ?, ?),
        (?, NULL, NULL, NULL, NULL, ?, ?)
    `).bind(
      'oa-session-recent',
      onboardingRecentEmail,
      new Date(Date.now() - 60_000).toISOString(),
      new Date(Date.now() - 30_000).toISOString(),
      'oa-session-secondary',
      onboardingSecondaryEmail,
      new Date(Date.now() - 50_000).toISOString(),
      new Date(Date.now() - 20_000).toISOString(),
      'oa-session-empty',
      new Date(Date.now() - 40_000).toISOString(),
      new Date(Date.now() - 10_000).toISOString()
    ).run();
  });

  it('should return all users with subscription data for the admin session', async () => {
    const res = await app.request('/api/admin/users', {
      headers: { 'X-Session-Id': adminSessionId },
    }, env);

    expect(res.status).toBe(200);
    const data = await res.json() as any;
    expect(Array.isArray(data.users)).toBe(true);
    expect(data.users.length).toBeGreaterThanOrEqual(2);
    expect(data.page).toBe(0);
    expect(data.pageSize).toBe(25);
    expect(data.totalCount).toBeGreaterThanOrEqual(2);
    expect(data.overallCount).toBeGreaterThanOrEqual(data.totalCount);

    const premium = data.users.find((user: any) =>
      user.email?.startsWith('admin_premium_')
    );
    expect(premium).toBeTruthy();
    expect(premium.subscription).toBeTruthy();
    expect(premium.subscription.provider).toBe('aliolo_manual');
    expect(premium.subscription.status).toBe('active');
  });

  it('should reject non-admin users', async () => {
    const res = await app.request('/api/admin/users', {
      headers: { 'X-Session-Id': normalSessionId },
    }, env);

    expect(res.status).toBe(403);
  });

  it('should return subject usage statistics for admin users', async () => {
    const res = await app.request('/api/admin/subject-usage', {
      headers: { 'X-Session-Id': adminSessionId },
    }, env);

    expect(res.status).toBe(200);
    const data = await res.json() as any[];
    const row = data.find((item) => item.subject_id === usageSubjectId);

    expect(row).toBeTruthy();
    expect(row.subject_name).toBe('Admin Usage Subject');
    expect(row.total_started).toBe(6);
    expect(row.total_completed).toBe(4);
    expect(row.learn_started).toBe(4);
    expect(row.test_started).toBe(2);
    expect(row.completion_rate).toBeCloseTo(4 / 6);
  });

  it('should reject subject usage statistics for non-admin users', async () => {
    const res = await app.request('/api/admin/subject-usage', {
      headers: { 'X-Session-Id': normalSessionId },
    }, env);

    expect(res.status).toBe(403);
  });

  it('should return onboarding analytics statistics for admin users', async () => {
    const res = await app.request('/api/admin/onboarding-analytics', {
      headers: { 'X-Session-Id': adminSessionId },
    }, env);

    expect(res.status).toBe(200);
    const data = await res.json() as any;

    expect(data.summary.total_sessions).toBeGreaterThanOrEqual(3);
    expect(data.summary.linked_email_sessions).toBeGreaterThanOrEqual(2);
    expect(data.summary.age_selected_sessions).toBeGreaterThanOrEqual(2);
    expect(data.summary.pillar_selected_sessions).toBeGreaterThanOrEqual(2);
    expect(data.summary.final_slide_sessions).toBeGreaterThanOrEqual(1);
    expect(data.summary.unique_emails).toBeGreaterThanOrEqual(2);
    expect(data.summary.completion_rate).toBeCloseTo(1 / 3, 1);
    expect(Array.isArray(data.recent_sessions)).toBe(true);
    expect(data.recent_sessions.length).toBeGreaterThanOrEqual(3);

    const recent = data.recent_sessions.find((row: any) => row.session_id === 'oa-session-recent');
    expect(recent).toBeTruthy();
    expect(recent.user_email).toBe(onboardingRecentEmail);
    expect(recent.age_range).toBe('age_15_18');
    expect(recent.pillar_id).toBe(6);
    expect(recent.pillar_name).toBe('Academic & Professional');
    expect(recent.last_slide_index).toBe(6);

    const ageBreakdown = data.age_breakdown.find((row: any) => row.age_range === 'age_15_18');
    expect(ageBreakdown.sessions).toBeGreaterThanOrEqual(1);

    const pillarBreakdown = data.pillar_breakdown.find((row: any) => row.pillar_id === 6);
    expect(pillarBreakdown.pillar_name).toBe('Academic & Professional');
    expect(pillarBreakdown.sessions).toBeGreaterThanOrEqual(1);
  });

  it('should reject onboarding analytics statistics for non-admin users', async () => {
    const res = await app.request('/api/admin/onboarding-analytics', {
      headers: { 'X-Session-Id': normalSessionId },
    }, env);

    expect(res.status).toBe(403);
  });

  it('should update a user subscription as admin', async () => {
    const res = await app.request(`/api/admin/users/${premiumUserId}/subscription`, {
      method: 'PATCH',
      body: JSON.stringify({
        status: 'inactive',
        expiry_date: '2027-01-01T00:00:00Z',
      }),
      headers: {
        'Content-Type': 'application/json',
        'X-Session-Id': adminSessionId,
      },
    }, env);

    expect(res.status).toBe(200);

    const subscription = await env.DB.prepare(
      'SELECT status, ends_at FROM manual_subscription_grants WHERE user_id = ? ORDER BY updated_at DESC LIMIT 1'
    ).bind(premiumUserId).first() as any;
    const profile = await env.DB.prepare(
      'SELECT is_premium FROM profiles WHERE id = ?'
    ).bind(premiumUserId).first() as any;

    expect(subscription.status).toBe('inactive');
    expect(profile.is_premium).toBe(0);
  });

  it('should return premium users from provider subscriptions without a snapshot table', async () => {
    const providerUser = await signupUser({
      email: `admin_provider_${Date.now()}@test.com`,
      password: 'password123',
    });
    await env.DB.prepare(`
      INSERT INTO provider_subscriptions (
        id,
        user_id,
        provider,
        status,
        external_subscription_id,
        product_id,
        current_period_end,
        created_at,
        updated_at
      ) VALUES (?, ?, 'google_play', 'active', ?, 'aliolo_premium_yearly', DATE(CURRENT_TIMESTAMP, '+1 year'), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    `).bind('provider-admin-test', providerUser.user.id, `google-admin-${Date.now()}`).run();
    await env.DB.prepare(
      'UPDATE profiles SET is_premium = 1 WHERE id = ?'
    ).bind(providerUser.user.id).run();

    const res = await app.request('/api/admin/users?filter=premium&includeFake=true', {
      headers: { 'X-Session-Id': adminSessionId },
    }, env);

    expect(res.status).toBe(200);
    const data = await res.json() as any;
    const premium = data.users.find((user: any) => user.id === providerUser.user.id);
    expect(premium.subscription.provider).toBe('google_play');
    expect(premium.subscription.effective_source).toBe('provider');
  });
});
