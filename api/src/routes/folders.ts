import { OpenAPIHono, createRoute, z } from '@hono/zod-openapi';
import type { AppEnv } from '../types';
import { FoldersResponseSchema, CreateFolderSchema } from '../schemas/folder';
import { SuccessResponseSchema, ErrorResponseSchema } from '../schemas/shared';

const router = new OpenAPIHono<AppEnv>();

const listFoldersRoute = createRoute({
  method: 'get',
  path: '/',
  summary: 'List folders',
  request: {
    query: z.object({
      pillar_id: z.string().optional().openapi({ description: 'Filter by pillar ID' }),
    }),
  },
  responses: {
    200: { content: { 'application/json': { schema: FoldersResponseSchema } }, description: 'Success' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(listFoldersRoute, async (c) => {
    const { pillar_id: pillarId } = c.req.valid('query');

    let query = 'SELECT f.*, p.username as owner_name FROM folders f LEFT JOIN profiles p ON f.owner_id = p.id WHERE 1=1';
    const params: any[] = [];

    if (pillarId) {
        query += ' AND f.pillar_id = ?';
        params.push(pillarId);
    }

    try {
        const { results } = await c.env.DB.prepare(query).bind(...params).all();
        return c.json(results as any, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

const createFolderRoute = createRoute({
  method: 'post',
  path: '/',
  summary: 'Create or update folder',
  request: {
    body: { content: { 'application/json': { schema: CreateFolderSchema } } }
  },
  responses: {
    200: { content: { 'application/json': { schema: SuccessResponseSchema } }, description: 'Success' },
    401: { description: 'Unauthorized' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(createFolderRoute, async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' } as any, 401);

    const { id, pillar_id, name, names } = c.req.valid('json');

    try {
        await c.env.DB.prepare(`
            INSERT INTO folders (id, pillar_id, owner_id, name, names, updated_at)
            VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(id) DO UPDATE SET
                pillar_id = excluded.pillar_id,
                name = excluded.name,
                names = excluded.names,
                updated_at = CURRENT_TIMESTAMP
        `).bind(id, pillar_id, user.id, name, JSON.stringify(names)).run();
        
        return c.json({ success: true }, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

const deleteFolderRoute = createRoute({
  method: 'delete',
  path: '/{id}',
  summary: 'Delete folder',
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

router.openapi(deleteFolderRoute, async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' } as any, 401);
    const { id } = c.req.valid('param');

    try {
        const f: any = await c.env.DB.prepare("SELECT owner_id FROM folders WHERE id = ?").bind(id).first();
        if (!f || f.owner_id !== user.id) return c.json({ error: 'Forbidden' } as any, 403);

        await c.env.DB.prepare("DELETE FROM folders WHERE id = ?").bind(id).run();
        return c.json({ success: true }, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

export default router;
