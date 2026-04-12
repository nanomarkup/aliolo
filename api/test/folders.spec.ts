import { describe, it, expect, beforeAll } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';

describe('Folders API', () => {
  let sessionId: string;

  beforeAll(async () => {
    const timestamp = Date.now();
    const res = await app.request('/api/auth/signup', {
      method: 'POST',
      body: JSON.stringify({ email: `folders_${timestamp}@test.com`, password: 'password123' }),
      headers: { 'Content-Type': 'application/json' }
    }, env);
    const data = await res.json() as any;
    sessionId = data.session_id;

    await env.DB.prepare("INSERT INTO pillars (id, sort_order) VALUES (1, 1)").run();
  });

  it('should create a folder', async () => {
    const folder = {
      id: 'test-folder',
      pillar_id: 1,
      localized_data: { en: { name: 'My Folder' } }
    };

    const res = await app.request('/api/folders', {
      method: 'POST',
      body: JSON.stringify(folder),
      headers: { 
        'Content-Type': 'application/json',
        'X-Session-Id': sessionId
      }
    }, env);

    expect(res.status).toBe(200);
  });

  it('should list folders', async () => {
    const res = await app.request('/api/folders?pillar_id=1', {
      headers: { 'X-Session-Id': sessionId }
    }, env);

    expect(res.status).toBe(200);
    const data = await res.json() as any[];
    expect(data.length).toBeGreaterThan(0);
  });

  it('should delete a folder', async () => {
    const res = await app.request('/api/folders/test-folder', {
      method: 'DELETE',
      headers: { 'X-Session-Id': sessionId }
    }, env);

    expect(res.status).toBe(200);
  });
});
