import { describe, it, expect, beforeAll } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';

describe('Analytics API', () => {
  it('should record onboarding analytics', async () => {
    const payload = {
      session_id: `session_${Date.now()}`,
      age_range: '7_14',
      pillar_id: 1,
      last_slide_index: 5
    };

    const res = await app.request('/api/analytics/onboarding', {
      method: 'POST',
      body: JSON.stringify(payload),
      headers: { 'Content-Type': 'application/json' }
    }, env);

    expect(res.status).toBe(200);
  });
});
