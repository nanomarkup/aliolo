import { describe, it, expect, beforeAll } from 'vitest';
import { execSync } from 'child_process';

const PROD_URL = 'https://aliolo.com';

// Helper to query remote D1 database directly
function queryD1(query: string): any[] {
  try {
    const output = execSync(`npx wrangler d1 execute aliolo-db --remote --command "${query}" --json`, {
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'ignore'], // Ignore stderr to keep test output clean
    });
    const parsed = JSON.parse(output);
    // Wrangler typically returns an array of objects for SELECT statements in --json mode
    if (parsed && parsed.length > 0 && parsed[0].results) {
      return parsed[0].results;
    }
    return parsed;
  } catch (error: any) {
    console.error('Failed to execute D1 query. Make sure wrangler is authenticated.');
    throw error;
  }
}

describe('E2E Data Integrity: API vs Database', () => {
  const mainUserEmail = 'aliolo@nohainc.com';
  const testUserEmail = process.env.TEST_USER_EMAIL || 'test@aliolo.com';
  
  const mainUserPassword = process.env.MAIN_USER_PASSWORD;
  const testUserPassword = process.env.TEST_USER_PASSWORD;

  let mainSessionId: string | null = null;
  let testSessionId: string | null = null;

  beforeAll(async () => {
    // Authenticate Main User
    if (mainUserPassword) {
      const mainRes = await fetch(`${PROD_URL}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: mainUserEmail, password: mainUserPassword }),
      });
      if (mainRes.ok) {
        const data = await mainRes.json();
        mainSessionId = data.session_id;
      } else {
        console.warn('Main user login failed. Ensure MAIN_USER_PASSWORD is correct.');
      }
    } else {
      console.warn('MAIN_USER_PASSWORD environment variable is missing.');
    }

    // Authenticate Test User
    if (testUserPassword) {
      const testRes = await fetch(`${PROD_URL}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: testUserEmail, password: testUserPassword }),
      });
      if (testRes.ok) {
        const data = await testRes.json();
        testSessionId = data.session_id;
      } else {
        console.warn('Test user login failed. Ensure TEST_USER_PASSWORD is correct.');
      }
    } else {
      console.warn('TEST_USER_PASSWORD environment variable is missing.');
    }
  });

  it('Main User: API response for subjects matches database records and validates filters', async () => {
    if (!mainSessionId) {
      console.log('Skipping test due to missing authentication');
      return;
    }

    // Fetch subjects via API
    const apiRes = await fetch(`${PROD_URL}/api/subjects?filter=all`, {
      headers: { 'X-Session-Id': mainSessionId }
    });
    expect(apiRes.status).toBe(200);
    const apiSubjects = await apiRes.json() as any[];

    // Fetch subjects directly from the database
    const mainUserDb = queryD1(`SELECT id FROM profiles WHERE email = '${mainUserEmail}'`);
    expect(mainUserDb.length).toBeGreaterThan(0);
    const ownerId = mainUserDb[0].id;

    const dbSubjects = queryD1(`SELECT * FROM subjects WHERE is_public = 1 OR owner_id = '${ownerId}'`);

    // Verify counts match
    expect(apiSubjects.length).toBe(dbSubjects.length);

    // Pick a subject to verify deep filter logic (source, age group, and language fields)
    if (apiSubjects.length > 0) {
      const apiSubj = apiSubjects[0];
      const dbSubj = dbSubjects.find(s => s.id === apiSubj.id);
      expect(dbSubj).toBeDefined();

      // Check standard fields (Source/Pillar, Age)
      expect(apiSubj.pillar_id).toBe(dbSubj.pillar_id);
      expect(apiSubj.age_group).toBe(dbSubj.age_group);
      expect(apiSubj.is_public).toBe(dbSubj.is_public);
      
      // Verify localized data integrity for language filtering
      const locData = JSON.parse(dbSubj.localized_data || '{}');
      // The API should return the exact same localized_data object (stringified)
      expect(apiSubj.localized_data).toBeDefined();
      const apiLocData = JSON.parse(apiSubj.localized_data);
      
      // Ensure language keys match (e.g., 'en', 'es', etc.)
      expect(Object.keys(apiLocData)).toEqual(Object.keys(locData));
    }
  });

  it('Test User: API response correctly filters out private subjects owned by others', async () => {
    if (!testSessionId) {
      console.log('Skipping test due to missing authentication');
      return;
    }

    const apiRes = await fetch(`${PROD_URL}/api/subjects?filter=all`, {
      headers: { 'X-Session-Id': testSessionId }
    });
    expect(apiRes.status).toBe(200);
    const apiSubjects = await apiRes.json() as any[];

    const testUserDb = queryD1(`SELECT id FROM profiles WHERE email = '${testUserEmail}'`);
    expect(testUserDb.length).toBeGreaterThan(0);
    const ownerId = testUserDb[0].id;

    const dbSubjects = queryD1(`SELECT * FROM subjects WHERE is_public = 1 OR owner_id = '${ownerId}'`);

    expect(apiSubjects.length).toBe(dbSubjects.length);
  });
});
