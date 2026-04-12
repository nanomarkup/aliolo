import { Hono } from 'hono';
import type { AppEnv } from '../types';

const router = new Hono<AppEnv>();

router.post('/onboarding', async (c) => {
    const body = await c.req.json();
    const { session_id, age_range, pillar_id, last_slide_index } = body;
    console.log('Onboarding Analytics:', body);

    try {
        const result = await c.env.DB.prepare(`
            INSERT INTO onboarding_analytics (session_id, age_range, pillar_id, last_slide_index, updated_at)
            VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(session_id) DO UPDATE SET
                age_range = COALESCE(excluded.age_range, onboarding_analytics.age_range),
                pillar_id = COALESCE(excluded.pillar_id, onboarding_analytics.pillar_id),
                last_slide_index = COALESCE(excluded.last_slide_index, onboarding_analytics.last_slide_index),
                updated_at = CURRENT_TIMESTAMP
        `).bind(session_id, age_range || null, pillar_id || null, last_slide_index !== undefined ? last_slide_index : null).run();
        
        console.log('Onboarding Analytics Success:', result);
        return c.json({ success: true });
    } catch (e: any) {
        console.error('Onboarding Analytics Error:', e);
        return c.json({ error: e.message }, 500);
    }
});

export default router;