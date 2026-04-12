import { describe, it, expect, beforeAll } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';

describe('Subjects API', () => {
  let userId: string;
  let sessionId: string;

  beforeAll(async () => {
    const timestamp = Date.now();
    const res = await app.request('/api/auth/signup', {
      method: 'POST',
      body: JSON.stringify({ email: `subj_${timestamp}@test.com`, password: 'password123' }),
      headers: { 'Content-Type': 'application/json' }
    }, env);
    const data = await res.json() as any;
    userId = data.user.id;
    sessionId = data.session_id;

    await env.DB.prepare("INSERT INTO pillars (id, sort_order) VALUES (1, 1)").run();
  });

  it('should create a subject', async () => {
    const subject = {
      id: 'test-subject',
      pillar_id: 1,
      folder_id: null,
      is_public: true,
      age_group: 'primary',
      localized_data: { en: { name: 'Test Subject' } }
    };

    const res = await app.request('/api/subjects', {
      method: 'POST',
      body: JSON.stringify(subject),
      headers: { 
        'Content-Type': 'application/json',
        'X-Session-Id': sessionId
      }
    }, env);

    if (res.status !== 200) {
        console.error('Subject creation failed:', await res.json());
    }
    expect(res.status).toBe(200);
  });

  it('should list subjects', async () => {
    const res = await app.request('/api/subjects?filter=all', {
      headers: { 'X-Session-Id': sessionId }
    }, env);

    expect(res.status).toBe(200);
    const data = await res.json() as any[];
    expect(data.length).toBeGreaterThan(0);
  });

  it('should delete a subject', async () => {
    const res = await app.request('/api/subjects/test-subject', {
      method: 'DELETE',
      headers: { 'X-Session-Id': sessionId }
    }, env);

    expect(res.status).toBe(200);
  });
});
