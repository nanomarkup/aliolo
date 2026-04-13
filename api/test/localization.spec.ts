import { describe, it, expect, beforeAll } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';

describe('Localization API', () => {
  beforeAll(async () => {
    await env.DB.prepare('INSERT INTO languages (id, name) VALUES (?, ?)').bind('en', 'English').run();
    await env.DB.prepare('INSERT INTO ui_translations (key, lang, value) VALUES (?, ?, ?)').bind('test.key', 'en', 'Test Value').run();
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

  it('should get translations for a language', async () => {
    const res = await app.request('/api/translations/en', {}, env);
    expect(res.status).toBe(200);
    const data = await res.json() as Record<string, string>;
    expect(typeof data).toBe('object');
    expect(data['test.key']).toBe('Test Value');
  });
});
