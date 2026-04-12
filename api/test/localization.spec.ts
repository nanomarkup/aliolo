import { describe, it, expect } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';

describe('Localization API', () => {
  it('should list languages', async () => {
    const res = await app.request('/api/languages', {}, env);
    expect(res.status).toBe(200);
    const data = await res.json();
    expect(Array.isArray(data)).toBe(true);
  });

  it('should get translations for a language', async () => {
    const res = await app.request('/api/translations/en', {}, env);
    expect(res.status).toBe(200);
    const data = await res.json();
    expect(typeof data).toBe('object');
  });
});
