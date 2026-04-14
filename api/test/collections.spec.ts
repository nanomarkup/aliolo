import { describe, it, expect, beforeAll } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';
import { signupUser } from './test-utils';

describe('Collections API', () => {
  let sessionId: string;

  beforeAll(async () => {
    const timestamp = Date.now();
    const data = await signupUser({ email: `coll_${timestamp}@test.com`, password: 'password123' });
    sessionId = data.session_id;

    await env.DB.prepare("INSERT INTO pillars (id, sort_order) VALUES (1, 1)").run();
  });

  it('should create a collection', async () => {
    const collection = {
      id: 'test-collection',
      pillar_id: 1,
      folder_id: null,
      is_public: true,
      age_group: 'advanced',
      name: 'My Collection',
      names: { en: 'My Collection' },
      description: 'My Desc',
      descriptions: { en: 'My Desc' }
    };

    const res = await app.request('/api/collections', {
      method: 'POST',
      body: JSON.stringify(collection),
      headers: { 
        'Content-Type': 'application/json',
        'X-Session-Id': sessionId
      }
    }, env);

    if (res.status !== 200) {
        console.error('Collection creation failed:', await res.json());
    }
    expect(res.status).toBe(200);
  });

  it('should list collections', async () => {
    const res = await app.request('/api/collections?pillar_id=1', {
      headers: { 'X-Session-Id': sessionId }
    }, env);

    expect(res.status).toBe(200);
    const data = await res.json() as any[];
    expect(data.length).toBeGreaterThan(0);
  });

  it('should get collection details', async () => {
    const res = await app.request('/api/collections/test-collection', {
      headers: { 'X-Session-Id': sessionId }
    }, env);

    expect(res.status).toBe(200);
    const data = await res.json() as any;
    expect(data.id).toBe('test-collection');
  });

  it('should delete a collection', async () => {
    const res = await app.request('/api/collections/test-collection', {
      method: 'DELETE',
      headers: { 'X-Session-Id': sessionId }
    }, env);

    expect(res.status).toBe(200);
  });
});
