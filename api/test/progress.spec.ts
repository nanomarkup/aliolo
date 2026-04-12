import { describe, it, expect, beforeAll } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';

describe('Progress API', () => {
  let sessionId: string;
  const cardId = 'test-progress-card';

  beforeAll(async () => {
    const timestamp = Date.now();
    const res = await app.request('/api/auth/signup', {
      method: 'POST',
      body: JSON.stringify({ email: `progress_${timestamp}@test.com`, password: 'password123' }),
      headers: { 'Content-Type': 'application/json' }
    }, env);
    const data = await res.json() as any;
    sessionId = data.session_id;

    await env.DB.prepare("INSERT INTO pillars (id, sort_order) VALUES (1, 1)").run();
    await env.DB.prepare("INSERT INTO subjects (id, pillar_id, owner_id) VALUES ('prog-subj', 1, ?)").bind(data.user.id).run();
    await env.DB.prepare("INSERT INTO cards (id, subject_id, owner_id) VALUES (?, 'prog-subj', ?)").bind(cardId, data.user.id).run();
  });

  it('should update progress', async () => {
    const progress = {
      card_id: cardId,
      subject_id: 'prog-subj',
      correct_count: 1,
      is_hidden: false
    };

    const res = await app.request('/api/progress', {
      method: 'POST',
      body: JSON.stringify(progress),
      headers: { 
        'Content-Type': 'application/json',
        'X-Session-Id': sessionId
      }
    }, env);

    expect(res.status).toBe(200);
  });

  it('should get card progress', async () => {
    const res = await app.request(`/api/progress/card/${cardId}`, {
      headers: { 'X-Session-Id': sessionId }
    }, env);

    expect(res.status).toBe(200);
    const data = await res.json() as any;
    expect(data.card_id).toBe(cardId);
  });

  it('should list hidden cards', async () => {
    // Hide the card first
    await app.request('/api/progress', {
      method: 'POST',
      body: JSON.stringify({ card_id: cardId, is_hidden: true }),
      headers: { 
        'Content-Type': 'application/json',
        'X-Session-Id': sessionId
      }
    }, env);

    const res = await app.request('/api/progress/hidden', {
      headers: { 'X-Session-Id': sessionId }
    }, env);

    expect(res.status).toBe(200);
    const data = await res.json() as any[];
    expect(data).toContain(cardId);
  });
});
