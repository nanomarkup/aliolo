import { Hono } from 'hono';
import type { AppEnv } from '../types';

const router = new Hono<AppEnv>();

router.get('/languages', async (c) => {
    try {
        const { results } = await c.env.DB.prepare(
            'SELECT id, name FROM languages ORDER BY name'
        ).all();
        return c.json(results);
    } catch (e: any) {
        return c.json({ error: e.message }, 500);
    }
});

router.get('/translations/:lang', async (c) => {
    const lang = c.req.param('lang');
    try {
        const { results } = await c.env.DB.prepare(
            'SELECT key, value FROM ui_translations WHERE lang = ?'
        ).bind(lang).all();
        
        const map: Record<string, string> = {};
        results.forEach((r: any) => {
            map[r.key] = r.value;
        });
        return c.json(map);
    } catch (e: any) {
        return c.json({ error: e.message }, 500);
    }
});

export default router;