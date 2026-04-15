import { describe, it, expect, beforeAll } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';
import { signupUser } from './test-utils';

describe('Feedbacks API', () => {
  let sessionId: string;
  let timestamp: number;

  beforeAll(async () => {
    timestamp = Date.now();
    const data = await signupUser({ email: `feedback_${timestamp}@test.com`, password: 'password123' });
    sessionId = data.session_id;
  });

  it('should submit feedback', async () => {
    const feedback = {
      id: 'test-feedback-id',
      type: 'bug',
      title: 'Test bug',
      content: 'Test bug report'
    };

    const res = await app.request('/api/feedbacks', {
      method: 'POST',
      body: JSON.stringify(feedback),
      headers: { 
        'Content-Type': 'application/json',
        'X-Session-Id': sessionId
      }
    }, env);

    if (res.status !== 200) {
        console.error('Feedback submission failed:', await res.json());
    }
    expect(res.status).toBe(200);
  });

  it('should list feedbacks', async () => {
    const res = await app.request('/api/feedbacks', {
      headers: { 'X-Session-Id': sessionId }
    }, env);

    expect(res.status).toBe(200);
    const data = await res.json() as any[];
    expect(Array.isArray(data)).toBe(true);
    expect(data.length).toBeGreaterThan(0);
  });

  it('should persist feedback and reply attachment URLs under feedbacks folder paths', async () => {
    const feedbackId = `feedback-folder-${timestamp}`;
    const replyId = `reply-folder-${timestamp}`;
    const feedbackAttachment =
      `https://aliolo.com/storage/v1/object/public/aliolo-media/feedbacks/${feedbackId}/attachment.png`;
    const replyAttachment =
      `https://aliolo.com/storage/v1/object/public/aliolo-media/feedbacks/${feedbackId}/${replyId}/reply.png`;

    const feedbackRes = await app.request('/api/feedbacks', {
      method: 'POST',
      body: JSON.stringify({
        id: feedbackId,
        type: 'bug',
        title: 'Feedback title',
        content: 'Feedback with attachment',
        attachment_urls: [feedbackAttachment],
      }),
      headers: {
        'Content-Type': 'application/json',
        'X-Session-Id': sessionId,
      },
    }, env);
    expect(feedbackRes.status).toBe(200);

    const feedbacksRes = await app.request('/api/feedbacks', {
      headers: { 'X-Session-Id': sessionId },
    }, env);
    expect(feedbacksRes.status).toBe(200);

    const feedbacks = await feedbacksRes.json() as any[];
    const feedback = feedbacks.find((item) => item.id === feedbackId);
    expect(feedback).toBeDefined();
    expect(feedback.attachment_urls).toContain(`/feedbacks/${feedbackId}/`);

    const replyRes = await app.request('/api/feedback_replies', {
      method: 'POST',
      body: JSON.stringify({
        id: replyId,
        feedback_id: feedbackId,
        content: 'Reply with attachment',
        attachment_urls: [replyAttachment],
      }),
      headers: {
        'Content-Type': 'application/json',
        'X-Session-Id': sessionId,
      },
    }, env);
    expect(replyRes.status).toBe(200);

    const repliesRes = await app.request(`/api/feedbacks/${feedbackId}/replies`, {
      headers: { 'X-Session-Id': sessionId },
    }, env);
    expect(repliesRes.status).toBe(200);

    const replies = await repliesRes.json() as any[];
    const reply = replies.find((item) => item.id === replyId);
    expect(reply).toBeDefined();
    expect(reply.attachment_urls).toContain(`/feedbacks/${feedbackId}/${replyId}/`);
  });
});
