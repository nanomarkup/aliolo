import { describe, it, expect } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';

describe('OpenAPI Docs Protection', () => {
  it('should return 200 for openapi.json on localhost', async () => {
    const res = await app.request('http://localhost/openapi.json', {}, env);
    expect(res.status).toBe(200);
  });

  it('should return 404 for openapi.json on non-local domain if ENVIRONMENT is not development', async () => {
    // Note: In Cloudflare Vitest pool, env.ENVIRONMENT might be undefined or different
    const res = await app.request('https://aliolo.com/openapi.json', {}, env);
    expect(res.status).toBe(404);
  });

  it('should return 200 for swagger ui on localhost', async () => {
    const res = await app.request('http://localhost/api/docs', {}, env);
    expect(res.status).toBe(200);
  });
});
