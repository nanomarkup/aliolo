import { OpenAPIHono, createRoute, z } from '@hono/zod-openapi';
import { generateId } from 'lucia';
import type { AppEnv } from '../types';
import { CollectionsResponseSchema, CollectionSchema, CreateCollectionSchema } from '../schemas/collection';
import { SuccessResponseSchema, ErrorResponseSchema } from '../schemas/shared';

const router = new OpenAPIHono<AppEnv>();

const listCollectionsRoute = createRoute({
  method: 'get',
  path: '/',
  summary: 'List collections',
  request: {
    query: z.object({
      pillar_id: z.string().optional().openapi({ description: 'Filter by pillar ID' }),
      folder_id: z.string().optional().openapi({ description: 'Filter by folder ID' }),
      root_only: z.string().optional().openapi({ description: 'If true, only collections without a folder' }),
      filter: z.enum(['all', 'favorites', 'mine', 'public']).optional().default('all'),
    }),
  },
  responses: {
    200: { content: { 'application/json': { schema: CollectionsResponseSchema } }, description: 'Success' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(listCollectionsRoute, async (c) => {
    const { pillar_id: pillarId, folder_id: folderId, root_only, filter } = c.req.valid('query');
    const isRootOnly = root_only === 'true';
    const userId = c.get("user")?.id;

    let query = `
        SELECT c.*, p.username as owner_name,
        (
            SELECT json_group_array(json_object('subject_id', ci.subject_id))
            FROM collection_items ci
            WHERE ci.collection_id = c.id
        ) as collection_items_json
        FROM collections c 
        LEFT JOIN profiles p ON c.owner_id = p.id`;
    
    if (filter === 'favorites' && userId) {
        query += ' JOIN user_subjects us ON c.id = us.collection_id WHERE us.user_id = ?';
    } else {
        query += ' WHERE 1=1';
    }

    const params: any[] = [];
    if (filter === 'favorites' && userId) {
        params.push(userId);
    }

    if (pillarId) {
        query += ' AND c.pillar_id = ?';
        params.push(pillarId);
    }

    if (folderId) {
        query += ' AND c.folder_id = ?';
        params.push(folderId);
    } else if (isRootOnly) {
        query += ' AND c.folder_id IS NULL';
    }

    if (filter === 'mine' && userId) {
        query += ' AND c.owner_id = ?';
        params.push(userId);
    } else if (filter === 'public') {
        query += ' AND c.is_public = 1';
    } else if (filter === 'all') {
        if (userId) {
            query += ' AND (c.is_public = 1 OR c.owner_id = ?)';
            params.push(userId);
        } else {
            query += ' AND c.is_public = 1';
        }
    }

    try {
        const { results } = await c.env.DB.prepare(query).bind(...params).all();
        
        let dashboardIds = new Set();
        if (userId) {
            const { results: dashboardRes } = await c.env.DB.prepare(
                'SELECT collection_id FROM user_subjects WHERE user_id = ? AND collection_id IS NOT NULL'
            ).bind(userId).all();
            dashboardIds = new Set(dashboardRes.map((r: any) => r.collection_id));
        }

        results.forEach((r: any) => {
            r.is_on_dashboard = dashboardIds.has(r.id);
            if (r.collection_items_json) {
                try {
                    const parsed = JSON.parse(r.collection_items_json);
                    r.collection_items = parsed.filter((item: any) => item.subject_id !== null);
                } catch (e) {
                    r.collection_items = [];
                }
                delete r.collection_items_json;
            } else {
                r.collection_items = [];
            }
        });

        return c.json(results as any, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

const getCollectionRoute = createRoute({
  method: 'get',
  path: '/{id}',
  summary: 'Get collection',
  request: {
    params: z.object({ id: z.string() })
  },
  responses: {
    200: { content: { 'application/json': { schema: CollectionSchema } }, description: 'Success' },
    404: { description: 'Not found' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(getCollectionRoute, async (c) => {
    const { id } = c.req.valid('param');
    const user = c.get("user");

    try {
        const result: any = await c.env.DB.prepare(
            'SELECT c.*, p.username as owner_name FROM collections c LEFT JOIN profiles p ON c.owner_id = p.id WHERE c.id = ?'
        ).bind(id).first();
        
        if (!result) return c.json({ error: 'Not found' } as any, 404);
        
        const { results: items } = await c.env.DB.prepare(
            'SELECT subject_id FROM collection_items WHERE collection_id = ?'
        ).bind(id).all();
        result.collection_items = items.filter((i: any) => i.subject_id !== null);

        if (user) {
            const dashboardCheck = await c.env.DB.prepare(
                'SELECT 1 FROM user_subjects WHERE user_id = ? AND collection_id = ?'
            ).bind(user.id, id).first();
            result.is_on_dashboard = !!dashboardCheck;
        }
        
        return c.json(result as any, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

const createCollectionRoute = createRoute({
  method: 'post',
  path: '/',
  summary: 'Create or update collection',
  request: {
    body: { content: { 'application/json': { schema: CreateCollectionSchema } } }
  },
  responses: {
    200: { content: { 'application/json': { schema: SuccessResponseSchema } }, description: 'Success' },
    401: { description: 'Unauthorized' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(createCollectionRoute, async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' } as any, 401);

    const { id, pillar_id, folder_id, is_public, age_group, localized_data, subject_ids } = c.req.valid('json');

    try {
        await c.env.DB.prepare(`
            INSERT INTO collections (id, pillar_id, folder_id, owner_id, is_public, age_group, localized_data, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(id) DO UPDATE SET
                pillar_id = excluded.pillar_id,
                folder_id = excluded.folder_id,
                is_public = excluded.is_public,
                age_group = excluded.age_group,
                localized_data = excluded.localized_data,
                updated_at = CURRENT_TIMESTAMP
        `).bind(id, pillar_id, folder_id, user.id, is_public ? 1 : 0, age_group, JSON.stringify(localized_data)).run();
        
        await c.env.DB.prepare("DELETE FROM collection_items WHERE collection_id = ?").bind(id).run();
        if (subject_ids && Array.isArray(subject_ids) && subject_ids.length > 0) {
            for (const sid of subject_ids) {
                await c.env.DB.prepare(
                    "INSERT INTO collection_items (id, collection_id, subject_id) VALUES (?, ?, ?)"
                ).bind(generateId(15), id, sid).run();
            }
        }

        return c.json({ success: true }, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

const deleteCollectionRoute = createRoute({
  method: 'delete',
  path: '/{id}',
  summary: 'Delete collection',
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

router.openapi(deleteCollectionRoute, async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' } as any, 401);
    const { id } = c.req.valid('param');

    try {
        const coll: any = await c.env.DB.prepare("SELECT owner_id FROM collections WHERE id = ?").bind(id).first();
        if (!coll || coll.owner_id !== user.id) return c.json({ error: 'Forbidden' } as any, 403);

        await c.env.DB.prepare("DELETE FROM collections WHERE id = ?").bind(id).run();
        return c.json({ success: true }, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

export default router;
