import { OpenAPIHono } from '@hono/zod-openapi';
import type { AppEnv } from '../types';

const router = new OpenAPIHono<AppEnv>();

router.get('/', async (c) => {
    const page = parseInt(c.req.query('page') || '0');
    const pageSize = parseInt(c.req.query('pageSize') || '20');
    const offset = page * pageSize;

    try {
        const { results } = await c.env.DB.prepare(`
            SELECT * FROM profiles 
            WHERE show_on_leaderboard = 1 
            ORDER BY total_xp DESC 
            LIMIT ? OFFSET ?
        `).bind(pageSize, offset).all();
        
        return c.json(results);
    } catch (e: any) {
        return c.json({ error: e.message }, 500);
    }
});

router.get('/rank', async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    try {
        const currentUser: any = await c.env.DB.prepare(
            "SELECT total_xp FROM profiles WHERE id = ?"
        ).bind(user.id).first();

        if (!currentUser) return c.json({ error: 'User not found' }, 404);

        const { results }: any = await c.env.DB.prepare(`
            SELECT COUNT(*) as count FROM profiles 
            WHERE show_on_leaderboard = 1 AND total_xp > ?
        `).bind(currentUser.total_xp).all();

        return c.json({ rank: results[0].count + 1 });
    } catch (e: any) {
        return c.json({ error: e.message }, 500);
    }
});

export default router;