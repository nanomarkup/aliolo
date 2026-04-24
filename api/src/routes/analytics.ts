import { OpenAPIHono } from '@hono/zod-openapi';
import { z } from '@hono/zod-openapi';
import type { AppEnv } from '../types';

const router = new OpenAPIHono<AppEnv>();

const subjectSessionSchema = z.object({
    subject_ids: z.array(z.string()).min(1),
    mode: z.enum(['learn', 'test']),
});

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

async function recordSubjectSession(c: any, column: 'started_count' | 'completed_count') {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const rawBody = await c.req.json().catch(() => ({}));
    const body = subjectSessionSchema.parse(rawBody);
    const subjectIds = [...new Set(body.subject_ids.map((id) => id.trim()).filter(Boolean))];
    if (subjectIds.length === 0) return c.json({ success: true });

    try {
        for (const subjectId of subjectIds) {
            await c.env.DB.prepare(`
                INSERT INTO subject_usage_stats (
                    subject_id,
                    mode,
                    started_count,
                    completed_count,
                    updated_at
                )
                VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
                ON CONFLICT(subject_id, mode) DO UPDATE SET
                    ${column} = ${column} + 1,
                    updated_at = CURRENT_TIMESTAMP
            `).bind(
                subjectId,
                body.mode,
                column === 'started_count' ? 1 : 0,
                column === 'completed_count' ? 1 : 0
            ).run();
        }
        return c.json({ success: true });
    } catch (e: any) {
        return c.json({ error: e.message }, 500);
    }
}

router.post('/subject-session/start', async (c) => {
    return recordSubjectSession(c, 'started_count');
});

router.post('/subject-session/complete', async (c) => {
    return recordSubjectSession(c, 'completed_count');
});

export default router;
