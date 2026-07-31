import { describe, it, expect } from 'vitest';

const PROD_URL = 'https://aliolo.com';

describe('Production API Health Check', () => {
  it('should return 200 for pillars', async () => {
    const res = await fetch(`${PROD_URL}/api/pillars`);
    expect(res.status).toBe(200);
    const data = await res.json();
    expect(Array.isArray(data)).toBe(true);
  });

  it('should return 200 for languages', async () => {
    const res = await fetch(`${PROD_URL}/api/languages`);
    expect(res.status).toBe(200);
    const data = await res.json();
    expect(Array.isArray(data)).toBe(true);
  });
});
