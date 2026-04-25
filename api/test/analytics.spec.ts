import { describe, it, expect } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';

describe('Analytics API', () => {
  it('updates onboarding analytics with the latest selected pillar and age', async () => {
    const sessionId = `analytics_${Date.now()}`;

    const firstRes = await app.request('/api/analytics/onboarding', {
      method: 'POST',
      body: JSON.stringify({
        session_id: sessionId,
        age_range: 'age_19_25',
        pillar_id: 6,
        last_slide_index: 2,
      }),
      headers: { 'Content-Type': 'application/json' },
    }, env);

    expect(firstRes.status).toBe(200);

    const secondRes = await app.request('/api/analytics/onboarding', {
      method: 'POST',
      body: JSON.stringify({
        session_id: sessionId,
        age_range: 'age_26_35',
        pillar_id: 7,
        last_slide_index: 3,
      }),
      headers: { 'Content-Type': 'application/json' },
    }, env);

    expect(secondRes.status).toBe(200);

    const analytics: any = await env.DB.prepare(
      'SELECT age_range, pillar_id, last_slide_index FROM onboarding_analytics WHERE session_id = ?'
    ).bind(sessionId).first();

    expect(analytics.age_range).toBe('age_26_35');
    expect(analytics.pillar_id).toBe(7);
    expect(analytics.last_slide_index).toBe(3);
  });
});
