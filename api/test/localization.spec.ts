import { describe, it, expect, beforeAll } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';

describe('Localization API', () => {
  beforeAll(async () => {
    await env.DB.prepare('INSERT INTO languages (id, name) VALUES (?, ?)').bind('en', 'English').run();
    await env.DB.prepare('INSERT OR REPLACE INTO ui_translations (key, lang, value) VALUES (?, ?, ?)').bind('test.key', 'zz-bundle', 'Bundle Source Value').run();
    await env.DB.prepare('INSERT OR REPLACE INTO ui_translations (key, lang, value) VALUES (?, ?, ?)').bind('test.key', 'zz-fallback', 'Fallback Source Value').run();
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
    await env.DB.prepare(
      'INSERT OR REPLACE INTO ui_translation_bundles (lang, translations) VALUES (?, ?)'
    ).bind('zz-bundle', JSON.stringify({ 'test.key': 'Bundle Value' })).run();

    const res = await app.request('/api/translations/zz-bundle', {}, env);
    expect(res.status).toBe(200);
    const data = await res.json() as Record<string, string>;
    expect(typeof data).toBe('object');
    expect(data['test.key']).toBe('Bundle Value');
  });

  it('should backfill a missing bundle from ui_translations', async () => {
    const res = await app.request('/api/translations/zz-fallback', {}, env);
    expect(res.status).toBe(200);

    const data = await res.json() as Record<string, string>;
    expect(data['test.key']).toBe('Fallback Source Value');

    const bundle = await env.DB.prepare(
      'SELECT translations FROM ui_translation_bundles WHERE lang = ?'
    ).bind('zz-fallback').first<{ translations: string }>();

    expect(bundle).toBeTruthy();
    expect(JSON.parse(bundle!.translations)['test.key']).toBe('Fallback Source Value');
  });
});
