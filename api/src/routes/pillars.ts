import { OpenAPIHono, createRoute, z } from '@hono/zod-openapi';
import type { AppEnv } from '../types';
import { PillarsResponseSchema } from '../schemas/pillar';

const router = new OpenAPIHono<AppEnv>();

const pillarsRoute = createRoute({
  method: 'get',
  path: '/',
  summary: 'Get all pillars',
  description: 'Returns a list of all learning pillars with their counts based on the filter.',
  request: {
    query: z.object({
      filter: z.enum(['all', 'favorites', 'mine', 'public'])
        .optional()
        .default('all')
        .openapi({ description: 'Filter the pillars based on content ownership or status' }),
    }),
  },
  responses: {
    200: {
      content: {
        'application/json': {
          schema: PillarsResponseSchema,
        },
      },
      description: 'The list of pillars',
    },
    500: {
      description: 'Internal server error',
    },
  },
});

router.openapi(pillarsRoute, async (c) => {
  const user = c.get("user");
  const userId = user?.id || null;
  const { filter } = c.req.valid('query');

  let subjectSubquery = '';
  let collectionSubquery = '';
  let folderSubquery = '';

  if (filter === 'favorites' && userId) {
    subjectSubquery = `SELECT COUNT(*) FROM subjects s JOIN user_subjects us ON s.id = us.subject_id WHERE s.pillar_id = p.id AND us.user_id = ?`;
    collectionSubquery = `SELECT COUNT(*) FROM collections c JOIN user_subjects us ON c.id = us.collection_id WHERE c.pillar_id = p.id AND us.user_id = ?`;
  } else if (filter === 'mine' && userId) {
    subjectSubquery = `SELECT COUNT(*) FROM subjects s WHERE s.pillar_id = p.id AND s.owner_id = ?`;
    collectionSubquery = `SELECT COUNT(*) FROM collections c WHERE c.pillar_id = p.id AND c.owner_id = ?`;
  } else if (filter === 'public') {
    subjectSubquery = `SELECT COUNT(*) FROM subjects s WHERE s.pillar_id = p.id AND s.is_public = 1`;
    collectionSubquery = `SELECT COUNT(*) FROM collections c WHERE c.pillar_id = p.id AND c.is_public = 1`;
  } else {
    // Default 'all'
    subjectSubquery = `SELECT COUNT(*) FROM subjects s WHERE s.pillar_id = p.id AND (s.is_public = 1 OR s.owner_id = ?)`;
    collectionSubquery = `SELECT COUNT(*) FROM collections c WHERE c.pillar_id = p.id AND (c.is_public = 1 OR c.owner_id = ?)`;
  }

  // Folders are filtered similarly but usually folders are either system-owned or user-owned
  folderSubquery = `SELECT COUNT(*) FROM folders f WHERE f.pillar_id = p.id AND (f.owner_id = ? OR f.owner_id IN (SELECT id FROM profiles WHERE username = 'Aliolo'))`;

  const bindParams: any[] = [];
  if (filter === 'favorites' || filter === 'mine' || filter === 'all') {
    bindParams.push(userId, userId, userId);
  } else {
    // filter === 'public', folderSubquery still needs userId
    bindParams.push(userId);
  }

  try {
    const { results } = await c.env.DB.prepare(`
        SELECT p.*, 
        (
          (${subjectSubquery}) +
          (${collectionSubquery})
        ) as subject_count,
        (${folderSubquery}) as folder_count
        FROM pillars p 
        ORDER BY p.sort_order ASC
    `).bind(...bindParams).all();
    return c.json(results as any, 200);
  } catch (e: any) {
    return c.json({ error: e.message } as any, 500);
  }
});

export default router;
