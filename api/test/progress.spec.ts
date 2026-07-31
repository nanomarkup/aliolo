import { describe, it, expect, beforeAll } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';
import { signupUser } from './test-utils';

describe('Progress API', () => {
  let sessionId: string;
  let userId: string;
  let cardId: string = 'test-card-prog';
  const subjectId = 'prog-subj';
  const reviewCardIds = [
    'review-due-old',
    'review-due-newer',
    'review-new',
    'review-never',
    'review-future',
    'review-hidden',
  ];

  beforeAll(async () => {
    const timestamp = Date.now();
    const data = await signupUser({ email: `prog_${timestamp}@test.com`, password: 'password123' });
    sessionId = data.session_id;
    userId = data.user.id;

    await env.DB.prepare("INSERT OR IGNORE INTO pillars (id, sort_order) VALUES (1, 1)").run();
    await env.DB.prepare("INSERT INTO subjects (id, pillar_id, owner_id) VALUES (?, 1, ?)").bind(subjectId, data.user.id).run();
    await env.DB.prepare("INSERT INTO cards (id, subject_id, owner_id) VALUES (?, ?, ?)").bind(cardId, subjectId, data.user.id).run();
    for (const id of reviewCardIds) {
      await env.DB.prepare("INSERT INTO cards (id, subject_id, owner_id) VALUES (?, ?, ?)").bind(id, subjectId, data.user.id).run();
    }
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
    expect(Array.isArray(data)).toBe(true);
  });

  it('should record a correct SM-2 review', async () => {
    const res = await app.request('/api/progress/review', {
      method: 'POST',
      body: JSON.stringify({
        card_id: 'review-new',
        subject_id: subjectId,
        quality: 5,
      }),
      headers: {
        'Content-Type': 'application/json',
        'X-Session-Id': sessionId,
      },
    }, env);

    expect(res.status).toBe(200);

    const progress = await env.DB.prepare(
      'SELECT correct_count, repetition_count, interval, ease_factor, next_review FROM progress WHERE user_id = ? AND card_id = ?'
    ).bind(userId, 'review-new').first() as any;

    expect(progress.correct_count).toBe(1);
    expect(progress.repetition_count).toBe(1);
    expect(progress.interval).toBe(1);
    expect(progress.ease_factor).toBeGreaterThan(2.5);
    expect(progress.next_review).toBeTruthy();
  });

  it('should reset repetition count on an incorrect SM-2 review', async () => {
    await env.DB.prepare(`
      INSERT INTO progress (
        user_id, card_id, subject_id, correct_count, repetition_count, interval, ease_factor, next_review
      ) VALUES (?, ?, ?, 3, 3, 10, 2.5, ?)
      ON CONFLICT(user_id, card_id) DO UPDATE SET
        correct_count = excluded.correct_count,
        repetition_count = excluded.repetition_count,
        interval = excluded.interval,
        ease_factor = excluded.ease_factor,
        next_review = excluded.next_review
    `).bind(userId, 'review-due-newer', subjectId, new Date(Date.now() - 86_400_000).toISOString()).run();

    const res = await app.request('/api/progress/review', {
      method: 'POST',
      body: JSON.stringify({
        card_id: 'review-due-newer',
        subject_id: subjectId,
        quality: 0,
      }),
      headers: {
        'Content-Type': 'application/json',
        'X-Session-Id': sessionId,
      },
    }, env);

    expect(res.status).toBe(200);

    const progress = await env.DB.prepare(
      'SELECT correct_count, repetition_count, interval, ease_factor, next_review FROM progress WHERE user_id = ? AND card_id = ?'
    ).bind(userId, 'review-due-newer').first() as any;

    expect(progress.correct_count).toBe(3);
    expect(progress.repetition_count).toBe(0);
    expect(progress.interval).toBe(1);
    expect(progress.ease_factor).toBeGreaterThanOrEqual(1.3);
    expect(Date.parse(progress.next_review)).toBeGreaterThan(Date.now());
  });

  it('should select due cards first, then never-tested cards', async () => {
    await env.DB.prepare(`
      INSERT INTO progress (
        user_id, card_id, subject_id, correct_count, repetition_count, interval, ease_factor, next_review, is_hidden
      ) VALUES (?, ?, ?, 1, 1, 1, 2.5, ?, 0)
      ON CONFLICT(user_id, card_id) DO UPDATE SET next_review = excluded.next_review, is_hidden = excluded.is_hidden
    `).bind(userId, 'review-due-old', subjectId, new Date(Date.now() - 172_800_000).toISOString()).run();

    await env.DB.prepare(`
      INSERT INTO progress (
        user_id, card_id, subject_id, correct_count, repetition_count, interval, ease_factor, next_review, is_hidden
      ) VALUES (?, ?, ?, 1, 1, 1, 2.5, ?, 0)
      ON CONFLICT(user_id, card_id) DO UPDATE SET next_review = excluded.next_review, is_hidden = excluded.is_hidden
    `).bind(userId, 'review-future', subjectId, new Date(Date.now() + 172_800_000).toISOString()).run();

    await env.DB.prepare(`
      INSERT INTO progress (
        user_id, card_id, subject_id, correct_count, repetition_count, interval, ease_factor, next_review, is_hidden
      ) VALUES (?, ?, ?, 1, 1, 1, 2.5, ?, 1)
      ON CONFLICT(user_id, card_id) DO UPDATE SET next_review = excluded.next_review, is_hidden = excluded.is_hidden
    `).bind(userId, 'review-hidden', subjectId, new Date(Date.now() - 172_800_000).toISOString()).run();

    const res = await app.request('/api/progress/review-session', {
      method: 'POST',
      body: JSON.stringify({
        card_ids: reviewCardIds,
        limit: 3,
      }),
      headers: {
        'Content-Type': 'application/json',
        'X-Session-Id': sessionId,
      },
    }, env);

    expect(res.status).toBe(200);
    const data = await res.json() as any;
    expect(data.card_ids).toEqual(['review-due-old', 'review-never']);
    expect(data.card_ids).not.toContain('review-future');
    expect(data.card_ids).not.toContain('review-hidden');
  });
});
