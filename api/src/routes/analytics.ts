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
                age_range = CASE
                    WHEN excluded.age_range IS NOT NULL THEN excluded.age_range
                    ELSE onboarding_analytics.age_range
                END,
                pillar_id = CASE
                    WHEN excluded.pillar_id IS NOT NULL THEN excluded.pillar_id
                    ELSE onboarding_analytics.pillar_id
                END,
                last_slide_index = CASE
                    WHEN excluded.last_slide_index IS NOT NULL THEN excluded.last_slide_index
                    ELSE onboarding_analytics.last_slide_index
                END,
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

    // Ignore test and admin users
    const isAdmin = user.id === 'usyeo7d2yzf2773';
    const isTestEmail = user.email === 'vitalii.noga@gmail.com';
    if (isAdmin || isTestEmail) {
        return c.json({ success: true, ignored: true });
    }

    const rawBody = await c.req.json().catch(() => ({}));
    const body = subjectSessionSchema.parse(rawBody);
    const subjectIds = [...new Set(body.subject_ids.map((id) => id.trim()).filter(Boolean))];
    if (subjectIds.length === 0) return c.json({ success: true });

    try {
        if (column === 'started_count') {
            for (const subjectId of subjectIds) {
                await c.env.DB.prepare(`
                    INSERT INTO subject_usage_stats (
                        subject_id,
                        user_id,
                        mode,
                        completed
                    )
                    VALUES (?, ?, ?, 0)
                `).bind(
                    subjectId,
                    user.id,
                    body.mode
                ).run();
            }
        } else {
            // Mark the most recent uncompleted session as completed for each subject
            for (const subjectId of subjectIds) {
                await c.env.DB.prepare(`
                    UPDATE subject_usage_stats
                    SET completed = 1
                    WHERE id = (
                        SELECT id FROM subject_usage_stats
                        WHERE subject_id = ? AND user_id = ? AND mode = ? AND completed = 0
                        ORDER BY created_at DESC
                        LIMIT 1
                    )
                `).bind(
                    subjectId,
                    user.id,
                    body.mode
                ).run();
            }
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
