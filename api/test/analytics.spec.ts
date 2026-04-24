import { describe, it, expect, beforeAll } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';
import { signupUser } from './test-utils';

describe('Analytics API', () => {
  let sessionId = '';
  let subjectId = '';

  beforeAll(async () => {
    const timestamp = Date.now();
    const data = await signupUser({
      email: `analytics_${timestamp}@test.com`,
      password: 'password123',
    });
    sessionId = data.session_id;
    subjectId = `analytics-subject-${timestamp}`;

    await env.DB.prepare("INSERT OR IGNORE INTO pillars (id, sort_order) VALUES (1, 1)").run();
    await env.DB.prepare(
      "INSERT INTO subjects (id, pillar_id, owner_id, name) VALUES (?, 1, ?, 'Analytics Subject')"
    ).bind(subjectId, data.user.id).run();
  });

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

  it('should record subject session starts and completions once per subject', async () => {
    const startRes = await app.request('/api/analytics/subject-session/start', {
      method: 'POST',
      body: JSON.stringify({
        subject_ids: [subjectId, subjectId],
        mode: 'learn',
      }),
      headers: {
        'Content-Type': 'application/json',
        'X-Session-Id': sessionId,
      },
    }, env);

    expect(startRes.status).toBe(200);

    const completeRes = await app.request('/api/analytics/subject-session/complete', {
      method: 'POST',
      body: JSON.stringify({
        subject_ids: [subjectId],
        mode: 'learn',
      }),
      headers: {
        'Content-Type': 'application/json',
        'X-Session-Id': sessionId,
      },
    }, env);

    expect(completeRes.status).toBe(200);

    const row = await env.DB.prepare(
      "SELECT started_count, completed_count FROM subject_usage_stats WHERE subject_id = ? AND mode = 'learn'"
    ).bind(subjectId).first() as any;

    expect(row.started_count).toBe(1);
    expect(row.completed_count).toBe(1);
  });

  it('should reject anonymous subject session analytics', async () => {
    const res = await app.request('/api/analytics/subject-session/start', {
      method: 'POST',
      body: JSON.stringify({
        subject_ids: [subjectId],
        mode: 'test',
      }),
      headers: { 'Content-Type': 'application/json' },
    }, env);

    expect(res.status).toBe(401);
  });
});
