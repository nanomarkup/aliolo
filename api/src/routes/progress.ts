import { OpenAPIHono, createRoute, z } from '@hono/zod-openapi';
import type { AppEnv } from '../types';
import { ProgressUpdateSchema, ProgressSchema } from '../schemas/progress';
import { SuccessResponseSchema, ErrorResponseSchema } from '../schemas/shared';

const router = new OpenAPIHono<AppEnv>();

const updateProgressRoute = createRoute({
  method: 'post',
  path: '/',
  summary: 'Update progress',
  request: {
    body: { content: { 'application/json': { schema: ProgressUpdateSchema } } }
  },
  responses: {
    200: { content: { 'application/json': { schema: SuccessResponseSchema } }, description: 'Success' },
    401: { description: 'Unauthorized' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(updateProgressRoute, async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' } as any, 401);

    const { card_id, subject_id, correct_count, is_hidden } = c.req.valid('json');
    console.log('Progress Update:', { userId: user.id, card_id, subject_id, correct_count, is_hidden });

    try {
        const result = await c.env.DB.prepare(`
            INSERT INTO progress (user_id, card_id, subject_id, correct_count, is_hidden, updated_at)
            VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(user_id, card_id) DO UPDATE SET
                correct_count = COALESCE(excluded.correct_count, progress.correct_count),
                is_hidden = COALESCE(excluded.is_hidden, progress.is_hidden),
                updated_at = CURRENT_TIMESTAMP
        `).bind(
            user.id, 
            card_id, 
            subject_id || null, 
            correct_count !== undefined ? correct_count : null, 
            is_hidden !== undefined ? (is_hidden ? 1 : 0) : null
        ).run();
        
        console.log('Progress Update Success:', result);
        return c.json({ success: true }, 200);
    } catch (e: any) {
        console.error('Progress Update Error:', e);
        return c.json({ error: e.message } as any, 500);
    }
});

const listHiddenRoute = createRoute({
  method: 'get',
  path: '/hidden',
  summary: 'List hidden cards',
  responses: {
    200: { content: { 'application/json': { schema: z.array(z.string()) } }, description: 'Success' },
    401: { description: 'Unauthorized' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(listHiddenRoute, async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' } as any, 401);

    try {
        const { results } = await c.env.DB.prepare(
            "SELECT card_id FROM progress WHERE user_id = ? AND is_hidden = 1"
        ).bind(user.id).all();
        return c.json(results.map((r: any) => r.card_id), 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

const getCardProgressRoute = createRoute({
  method: 'get',
  path: '/card/{card_id}',
  summary: 'Get card progress',
  request: {
    params: z.object({ card_id: z.string() })
  },
  responses: {
    200: { content: { 'application/json': { schema: ProgressSchema.nullable() } }, description: 'Success' },
    401: { description: 'Unauthorized' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(getCardProgressRoute, async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' } as any, 401);
    const { card_id } = c.req.valid('param');

    try {
        const result = await c.env.DB.prepare(
            "SELECT * FROM progress WHERE user_id = ? AND card_id = ?"
        ).bind(user.id, card_id).first();
        return c.json(result as any, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

export default router;
