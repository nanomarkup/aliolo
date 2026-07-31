import { describe, it, expect, beforeAll } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';
import { signupUser } from './test-utils';

describe('Cards API', () => {
  let sessionId: string;
  let subjectId: string = 'test-subject';

  beforeAll(async () => {
    const timestamp = Date.now();
    const data = await signupUser({ email: `cards_${timestamp}@test.com`, password: 'password123' });
    sessionId = data.session_id;

    await env.DB.prepare("INSERT INTO pillars (id, sort_order) VALUES (1, 1)").run();
    await env.DB.prepare("INSERT INTO subjects (id, pillar_id, owner_id) VALUES (?, 1, ?)").bind(subjectId, data.user.id).run();
  });

  it('should create a card', async () => {
    const card = {
      id: 'test-card',
      subject_id: subjectId,
      renderer: 'generic',
      answer: 'A',
      answers: { es: 'A' },
      prompt: 'Q',
      prompts: { es: 'Q' },
      display_text: '1 + 1',
      display_texts: { es: '1 + 1' },
      images_base: [],
      images_local: {},
      audio: '',
      audios: {},
      video: '',
      videos: {}
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
    expect(data[0]).toHaveProperty('renderer');
    expect(data[0]).toHaveProperty('display_text');
  });

  it('should delete a card', async () => {
    const res = await app.request('/api/cards/test-card', {
      method: 'DELETE',
      headers: { 'X-Session-Id': sessionId }
    }, env);

    expect(res.status).toBe(200);
  });
});
