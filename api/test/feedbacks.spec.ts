import { describe, it, expect, beforeAll } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';
import { signupUser } from './test-utils';

describe('Feedbacks API', () => {
  let sessionId: string;

  beforeAll(async () => {
    const timestamp = Date.now();
    const data = await signupUser({ email: `feedback_${timestamp}@test.com`, password: 'password123' });
    sessionId = data.session_id;
  });

  it('should submit feedback', async () => {
    const feedback = {
      id: 'test-feedback-id',
      type: 'bug',
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
});
