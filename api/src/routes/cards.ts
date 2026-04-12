import { OpenAPIHono, createRoute, z } from '@hono/zod-openapi';
import type { AppEnv } from '../types';
import { CardSchema, CardsResponseSchema, CreateCardSchema } from '../schemas/card';
import { SuccessResponseSchema, ErrorResponseSchema } from '../schemas/shared';

const router = new OpenAPIHono<AppEnv>();

const listCardsRoute = createRoute({
  method: 'get',
  path: '/',
  summary: 'List cards',
  request: {
    query: z.object({
      subject_id: z.string().openapi({ description: 'The ID of the subject' }),
    }),
  },
  responses: {
    200: { content: { 'application/json': { schema: CardsResponseSchema } }, description: 'Success' },
    400: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Bad Request' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(listCardsRoute, async (c) => {
  const { subject_id: subjectId } = c.req.valid('query');
  
  try {
    const { results } = await c.env.DB.prepare('SELECT * FROM cards WHERE subject_id = ? AND is_deleted = 0')
      .bind(subjectId)
      .all();
    return c.json(results as any, 200);
  } catch (e: any) {
    return c.json({ error: e.message } as any, 500);
  }
});

const createCardRoute = createRoute({
  method: 'post',
  path: '/',
  summary: 'Create or update card',
  request: {
    body: { content: { 'application/json': { schema: CreateCardSchema } } }
  },
  responses: {
    200: { content: { 'application/json': { schema: SuccessResponseSchema } }, description: 'Success' },
    401: { description: 'Unauthorized' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(createCardRoute, async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' } as any, 401);

    const { id, subject_id, level, test_mode, is_public, localized_data } = c.req.valid('json');

    try {
        await c.env.DB.prepare(`
            INSERT INTO cards (id, subject_id, owner_id, level, test_mode, is_public, localized_data, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(id) DO UPDATE SET
                subject_id = excluded.subject_id,
                level = excluded.level,
                test_mode = excluded.test_mode,
                is_public = excluded.is_public,
                localized_data = excluded.localized_data,
                updated_at = CURRENT_TIMESTAMP
        `).bind(id, subject_id, user.id, level || 1, test_mode || 'standard', is_public ? 1 : 0, JSON.stringify(localized_data)).run();
        
        return c.json({ success: true }, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

const deleteCardRoute = createRoute({
  method: 'delete',
  path: '/{id}',
  summary: 'Delete card',
  request: {
    params: z.object({ id: z.string() })
  },
  responses: {
    200: { content: { 'application/json': { schema: SuccessResponseSchema } }, description: 'Success' },
    401: { description: 'Unauthorized' },
    403: { description: 'Forbidden' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(deleteCardRoute, async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' } as any, 401);
    const { id } = c.req.valid('param');

    try {
        const card: any = await c.env.DB.prepare("SELECT owner_id FROM cards WHERE id = ?").bind(id).first();
        if (!card || card.owner_id !== user.id) return c.json({ error: 'Forbidden' } as any, 403);

        await c.env.DB.prepare("UPDATE cards SET is_deleted = 1, updated_at = CURRENT_TIMESTAMP WHERE id = ?").bind(id).run();
        return c.json({ success: true }, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

export default router;
