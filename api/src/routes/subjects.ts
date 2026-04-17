import { OpenAPIHono, createRoute, z } from '@hono/zod-openapi';
import type { AppEnv } from '../types';
import { 
  SubjectsResponseSchema, 
  CreateSubjectSchema, 
  ToggleDashboardSchema 
} from '../schemas/subject';
import { SuccessResponseSchema, ErrorResponseSchema } from '../schemas/shared';

const router = new OpenAPIHono<AppEnv>();

const subjectSelectColumns = `
  s.id,
  s.pillar_id,
  s.folder_id,
  s.owner_id,
  s.age_group,
  s.is_public,
  s.created_at,
  s.updated_at,
  s.names,
  s.description,
  s.descriptions,
  s.name,
  s.type
`;

const listSubjectsRoute = createRoute({
  method: 'get',
  path: '/subjects',
  summary: 'List subjects',
  request: {
    query: z.object({
      pillar_id: z.string().optional().openapi({ description: 'Filter by pillar ID' }),
      folder_id: z.string().optional().openapi({ description: 'Filter by folder ID' }),
      root_only: z.string().optional().openapi({ description: 'If true, only subjects without a folder' }),
      ids: z.string().optional().openapi({ description: 'Comma-separated list of IDs' }),
      filter: z.enum(['all', 'favorites', 'mine', 'public']).optional().default('all'),
    }),
  },
  responses: {
    200: { content: { 'application/json': { schema: SubjectsResponseSchema } }, description: 'Success' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(listSubjectsRoute, async (c) => {
  const { pillar_id: pillarId, folder_id: folderId, root_only, ids, filter } = c.req.valid('query');
  const isRootOnly = root_only === 'true';
  const userId = c.get("user")?.id;

    let query = `
    SELECT ${subjectSelectColumns}, p.username as owner_name, 
    (SELECT COUNT(*) FROM cards c WHERE c.subject_id = s.id) as card_count
    FROM subjects s 
    LEFT JOIN profiles p ON s.owner_id = p.id`;
  
  if (filter === 'favorites' && userId) {
    query += ' JOIN user_subjects us ON s.id = us.subject_id WHERE us.user_id = ?';
  } else {
    query += ' WHERE 1=1';
  }

  const params: any[] = [];
  if (filter === 'favorites' && userId) {
    params.push(userId);
  }

  if (ids) {
    const idList = ids.split(',');
    query += ` AND s.id IN (${idList.map(() => '?').join(',')})`;
    params.push(...idList);
  }

  if (pillarId) {
    query += ' AND s.pillar_id = ?';
    params.push(pillarId);
  }

  if (folderId) {
    query += ' AND s.folder_id = ?';
    params.push(folderId);
  } else if (isRootOnly) {
    query += ' AND s.folder_id IS NULL';
  }

  if (filter === 'mine' && userId) {
    query += ' AND s.owner_id = ?';
    params.push(userId);
  } else if (filter === 'public') {
    query += ' AND s.is_public = 1';
  } else if (filter === 'all') {
    if (userId) {
      query += ' AND (s.is_public = 1 OR s.owner_id = ?)';
      params.push(userId);
    } else {
      query += ' AND s.is_public = 1';
    }
  }

  try {
    const { results } = await c.env.DB.prepare(query).bind(...params).all();
    
    if (userId) {
        const { results: dashboardRes } = await c.env.DB.prepare(
            'SELECT subject_id FROM user_subjects WHERE user_id = ? AND subject_id IS NOT NULL'
        ).bind(userId).all();
        const dashboardIds = new Set(dashboardRes.map((r: any) => r.subject_id));
        
        results.forEach((s: any) => {
            s.is_on_dashboard = dashboardIds.has(s.id);
        });
    }

    return c.json(results as any, 200);
  } catch (e: any) {
    return c.json({ error: e.message } as any, 500);
  }
});

const createSubjectRoute = createRoute({
  method: 'post',
  path: '/subjects',
  summary: 'Create or update subject',
  request: {
    body: { content: { 'application/json': { schema: CreateSubjectSchema } } }
  },
  responses: {
    200: { content: { 'application/json': { schema: SuccessResponseSchema } }, description: 'Success' },
    401: { description: 'Unauthorized' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(createSubjectRoute, async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' } as any, 401);

    const { id, pillar_id, folder_id, is_public, age_group, name, names, description, descriptions } = c.req.valid('json');

    try {
        await c.env.DB.prepare(`
            INSERT INTO subjects (id, pillar_id, folder_id, owner_id, is_public, age_group, name, names, description, descriptions, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(id) DO UPDATE SET
                pillar_id = excluded.pillar_id,
                folder_id = excluded.folder_id,
                is_public = excluded.is_public,
                age_group = excluded.age_group,
                name = excluded.name,
                names = excluded.names,
                description = excluded.description,
                descriptions = excluded.descriptions,
                updated_at = CURRENT_TIMESTAMP
        `).bind(
            id, 
            pillar_id, 
            folder_id, 
            user.id, 
            is_public ? 1 : 0, 
            age_group, 
            name, 
            JSON.stringify(names), 
            description, 
            JSON.stringify(descriptions)
        ).run();
        
        return c.json({ success: true }, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

const deleteSubjectRoute = createRoute({
  method: 'delete',
  path: '/subjects/{id}',
  summary: 'Delete subject',
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

router.openapi(deleteSubjectRoute, async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' } as any, 401);
    const { id } = c.req.valid('param');

    try {
        const s: any = await c.env.DB.prepare("SELECT owner_id FROM subjects WHERE id = ?").bind(id).first();
        if (!s || s.owner_id !== user.id) return c.json({ error: 'Forbidden' } as any, 403);

        await c.env.DB.prepare("DELETE FROM subjects WHERE id = ?").bind(id).run();
        await c.env.DB.prepare("DELETE FROM cards WHERE subject_id = ?").bind(id).run();
        return c.json({ success: true }, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

const dashboardSubjectsRoute = createRoute({
  method: 'get',
  path: '/dashboard/subjects',
  summary: 'Get dashboard subjects',
  responses: {
    200: { content: { 'application/json': { schema: SubjectsResponseSchema } }, description: 'Success' },
    401: { description: 'Unauthorized' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(dashboardSubjectsRoute, async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' } as any, 401);

    try {
        const { results } = await c.env.DB.prepare(`
            SELECT ${subjectSelectColumns}, p.username as owner_name,
            (SELECT COUNT(*) FROM cards c WHERE c.subject_id = s.id) as card_count
            FROM subjects s
            INNER JOIN user_subjects us ON s.id = us.subject_id
            LEFT JOIN profiles p ON s.owner_id = p.id
            WHERE us.user_id = ?
        `).bind(user.id).all();
        
        results.forEach((s: any) => s.is_on_dashboard = true);
        return c.json(results as any, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

const toggleDashboardRoute = createRoute({
  method: 'post',
  path: '/dashboard/toggle',
  summary: 'Toggle subject on dashboard',
  request: {
    body: { content: { 'application/json': { schema: ToggleDashboardSchema } } }
  },
  responses: {
    200: { content: { 'application/json': { schema: SuccessResponseSchema } }, description: 'Success' },
    400: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Bad Request' },
    401: { description: 'Unauthorized' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(toggleDashboardRoute, async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' } as any, 401);

    const { subject_id, collection_id, show } = c.req.valid('json');
    if (!subject_id && !collection_id) return c.json({ error: 'subject_id or collection_id required' } as any, 400);

    try {
        if (show) {
            await c.env.DB.prepare(
                "INSERT OR IGNORE INTO user_subjects (user_id, subject_id, collection_id) VALUES (?, ?, ?)"
            ).bind(user.id, subject_id || null, collection_id || null).run();
        } else {
            if (subject_id) {
                await c.env.DB.prepare(
                    "DELETE FROM user_subjects WHERE user_id = ? AND subject_id = ?"
                ).bind(user.id, subject_id).run();
            } else if (collection_id) {
                await c.env.DB.prepare(
                    "DELETE FROM user_subjects WHERE user_id = ? AND collection_id = ?"
                ).bind(user.id, collection_id).run();
            }
        }
        return c.json({ success: true }, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

export default router;
