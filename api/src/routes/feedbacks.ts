import { Hono } from 'hono';
import type { AppEnv } from '../types';

const router = new Hono<AppEnv>();

router.get('/feedbacks', async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    try {
        let query = 'SELECT f.*, p.username as owner_name, p.email as owner_email FROM feedbacks f LEFT JOIN profiles p ON f.user_id = p.id';
        const params: any[] = [];

        if (user.id !== 'usyeo7d2yzf2773') {
            query += ' WHERE f.user_id = ?';
            params.push(user.id);
        }

        query += ' ORDER BY f.created_at DESC';

        const { results } = await c.env.DB.prepare(query).bind(...params).all();
        return c.json(results);
    } catch (e: any) {
        return c.json({ error: e.message }, 500);
    }
});

router.post('/feedbacks', async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const body = await c.req.json();
    const { id, type, content, attachment_urls, metadata, status } = body;

    try {
        await c.env.DB.prepare(`
            INSERT INTO feedbacks (id, user_id, type, content, attachment_urls, metadata, status, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(id) DO UPDATE SET
                content = excluded.content,
                status = excluded.status,
                updated_at = CURRENT_TIMESTAMP
        `).bind(
            id, user.id, type, content, 
            JSON.stringify(attachment_urls || []), 
            JSON.stringify(metadata || {}),
            status || 'open'
        ).run();
        
        return c.json({ success: true });
    } catch (e: any) {
        return c.json({ error: e.message }, 500);
    }
});

router.get('/feedbacks/:id/replies', async (c) => {
    const feedbackId = c.req.param('id');
    try {
        const { results } = await c.env.DB.prepare(
            'SELECT * FROM feedback_replies WHERE feedback_id = ? ORDER BY created_at ASC'
        ).bind(feedbackId).all();
        return c.json(results);
    } catch (e: any) {
        return c.json({ error: e.message }, 500);
    }
});

router.post('/feedback_replies', async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const body = await c.req.json();
    const { id, feedback_id, content, attachment_urls } = body;

    try {
        await c.env.DB.prepare(`
            INSERT INTO feedback_replies (id, feedback_id, user_id, content, attachment_urls)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                content = excluded.content,
                updated_at = CURRENT_TIMESTAMP
        `).bind(id, feedback_id || null, user.id, content, JSON.stringify(attachment_urls || [])).run();
        
        if (feedback_id) {
            const isAdmin = user.id === 'usyeo7d2yzf2773';
            const newStatus = isAdmin ? 'replied' : 'open';
            await c.env.DB.prepare(
                'UPDATE feedbacks SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?'
            ).bind(newStatus, feedback_id).run();
        }

        return c.json({ success: true });
    } catch (e: any) {
        return c.json({ error: e.message }, 500);
    }
});

router.delete('/feedback_replies/:id', async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' }, 401);
    const id = c.req.param('id');

    try {
        const reply: any = await c.env.DB.prepare("SELECT user_id FROM feedback_replies WHERE id = ?").bind(id).first();
        if (!reply || reply.user_id !== user.id) return c.json({ error: 'Forbidden' }, 403);

        await c.env.DB.prepare("DELETE FROM feedback_replies WHERE id = ?").bind(id).run();
        return c.json({ success: true });
    } catch (e: any) {
        return c.json({ error: e.message }, 500);
    }
});

router.get('/feedbacks/notifications', async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const isAdmin = user.id === 'usyeo7d2yzf2773';
    try {
        let countRes: any;
        if (isAdmin) {
            countRes = await c.env.DB.prepare(
                'SELECT COUNT(*) as count FROM feedbacks WHERE status = "open"'
            ).first();
        } else {
            countRes = await c.env.DB.prepare(
                'SELECT COUNT(*) as count FROM feedbacks WHERE user_id = ? AND status = "replied"'
            ).bind(user.id).first();
        }
        return c.json({ has_notif: countRes.count > 0 });
    } catch (e: any) {
        return c.json({ error: e.message }, 500);
    }
});

export default router;