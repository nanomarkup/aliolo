import { describe, it, expect, beforeAll } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';

describe('Pillars API', () => {
  beforeAll(async () => {
    // Initialize required schema for pillars subqueries
    try {
      await env.DB.prepare(`
        CREATE TABLE IF NOT EXISTS pillars (
          id INTEGER PRIMARY KEY,
          sort_order INTEGER,
          light_color TEXT,
          dark_color TEXT,
          icon TEXT,
          localized_data TEXT
        );
      `).run();

      await env.DB.prepare(`
        CREATE TABLE IF NOT EXISTS subjects (
          id TEXT PRIMARY KEY,
          pillar_id INTEGER REFERENCES pillars(id) NOT NULL,
          is_public INTEGER DEFAULT 0,
          owner_id TEXT
        );
      `).run();

      await env.DB.prepare(`
        CREATE TABLE IF NOT EXISTS collections (
          id TEXT PRIMARY KEY,
          pillar_id INTEGER REFERENCES pillars(id) NOT NULL,
          is_public INTEGER DEFAULT 0,
          owner_id TEXT
        );
      `).run();

      await env.DB.prepare(`
        CREATE TABLE IF NOT EXISTS folders (
          id TEXT PRIMARY KEY,
          pillar_id INTEGER REFERENCES pillars(id) NOT NULL,
          owner_id TEXT
        );
      `).run();

      await env.DB.prepare(`
        CREATE TABLE IF NOT EXISTS profiles (
          id TEXT PRIMARY KEY,
          username TEXT
        );
      `).run();

      // Insert dummy data
      await env.DB.prepare(`
        INSERT OR REPLACE INTO pillars (id, sort_order, light_color, dark_color, icon, localized_data)
        VALUES (1, 1, '#ffffff', '#000000', 'home', '{"en": {"name": "Test Pillar"}}');
      `).run();
    } catch (e) {
      console.error('Setup failed', e);
    }
  });

  it('should return a list of pillars', async () => {
    const res = await app.request('/api/pillars', {}, env);
    if (res.status !== 200) {
        console.error('Pillars request failed', await res.text());
    }
    expect(res.status).toBe(200);
    
    const data = await res.json() as any[];
    expect(data.length).toBeGreaterThan(0);
    expect(JSON.stringify(data[0].localized_data)).toContain('Test Pillar');
  });
});
