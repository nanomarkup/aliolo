import { describe, it, expect, beforeAll } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';
import { signupUser } from './test-utils';

describe('Admin Users API', () => {
  const adminUserId = 'usyeo7d2yzf2773';
  const adminSessionId = 'admin-session';
  const premiumSessionId = 'premium-session';
  const normalSessionId = 'normal-session';

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
    await env.DB.prepare(`
      INSERT OR REPLACE INTO sessions (id, user_id, expires_at)
      VALUES (?, ?, ?)
    `).bind(premiumSessionId, premium.user.id, Date.now() + 86_400_000).run();
    await env.DB.prepare(`
      INSERT OR REPLACE INTO user_subscriptions (
        id,
        user_id,
        status,
        provider,
        expiry_date,
        purchase_token,
        order_id,
        product_id,
        created_at,
        updated_at
      ) VALUES (?, ?, 'active', 'aliolo', DATE(CURRENT_TIMESTAMP, '+1 year'), 'token-1', 'order-1', 'premium_yearly', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    `).bind('sub-premium-user', premium.user.id).run();
  });

  it('should return all users with subscription data for the admin session', async () => {
    const res = await app.request('/api/admin/users', {
      headers: { 'X-Session-Id': adminSessionId },
    }, env);

    expect(res.status).toBe(200);
    const data = await res.json() as any[];
    expect(Array.isArray(data)).toBe(true);
    expect(data.length).toBeGreaterThanOrEqual(2);

    const premium = data.find((user) => user.email?.startsWith('admin_premium_'));
    expect(premium).toBeTruthy();
    expect(premium.subscription).toBeTruthy();
    expect(premium.subscription.provider).toBe('aliolo');
    expect(premium.subscription.status).toBe('active');
  });

  it('should reject non-admin users', async () => {
    const res = await app.request('/api/admin/users', {
      headers: { 'X-Session-Id': normalSessionId },
    }, env);

    expect(res.status).toBe(403);
  });
});
