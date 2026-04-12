import { describe, it, expect, beforeAll } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';

describe('Cards API', () => {
  let sessionId: string;
  const subjectId = 'test-card-subject';

  beforeAll(async () => {
    const timestamp = Date.now();
    const res = await app.request('/api/auth/signup', {
      method: 'POST',
      body: JSON.stringify({ email: `cards_${timestamp}@test.com`, password: 'password123' }),
      headers: { 'Content-Type': 'application/json' }
    }, env);
    const data = await res.json() as any;
    sessionId = data.session_id;

    await env.DB.prepare("INSERT INTO pillars (id, sort_order) VALUES (1, 1)").run();
    await env.DB.prepare("INSERT INTO subjects (id, pillar_id, owner_id) VALUES (?, 1, ?)").bind(subjectId, data.user.id).run();
  });

  it('should create a card', async () => {
    const card = {
      id: 'test-card',
      subject_id: subjectId,
      localized_data: { global: { answer: 'A' } }
    };

    const res = await app.request('/api/cards', {
      method: 'POST',
      body: JSON.stringify(card),
      headers: { 
        'Content-Type': 'application/json',
        'X-Session-Id': sessionId
      }
    }, env);

    expect(res.status).toBe(200);
  });

  it('should list cards for a subject', async () => {
    const res = await app.request(`/api/cards?subject_id=${subjectId}`, {
      headers: { 'X-Session-Id': sessionId }
    }, env);

    expect(res.status).toBe(200);
    const data = await res.json() as any[];
    expect(data.length).toBeGreaterThan(0);
  });

  it('should delete a card', async () => {
    const res = await app.request('/api/cards/test-card', {
      method: 'DELETE',
      headers: { 'X-Session-Id': sessionId }
    }, env);

    expect(res.status).toBe(200);
  });
});
