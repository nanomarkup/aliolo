import { describe, it, expect, beforeAll } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';

describe('Localization API', () => {
  beforeAll(async () => {
    await env.DB.prepare('INSERT INTO languages (id, name) VALUES (?, ?)').bind('en', 'English').run();
  });

  it('should list languages', async () => {
    const res = await app.request('/api/languages', {}, env);
    expect(res.status).toBe(200);
    const data = await res.json() as any[];
    expect(Array.isArray(data)).toBe(true);
    expect(data.length).toBeGreaterThan(0);
    expect(data[0].id).toBe('en');
    expect(data[0].name).toBe('English');
  });
});

