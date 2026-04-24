import { OpenAPIHono, createRoute, z } from '@hono/zod-openapi';
import { generateId } from 'lucia';
import type { AppEnv } from '../types';
import {
  AdminSubjectUsageResponseSchema,
  AdminUsersFilterSchema,
  AdminUsersResponseSchema,
} from '../schemas/admin';
import { ErrorResponseSchema, SuccessResponseSchema } from '../schemas/shared';

const router = new OpenAPIHono<AppEnv>();
const ADMIN_ID = 'usyeo7d2yzf2773';

const subscriptionUpdateSchema = z.object({
  status: z.enum(['active', 'inactive']),
  expiry_date: z.string().nullable().optional(),
});

const cardLimitUpdateSchema = z.object({
  card_limit: z.number().int().min(0),
});

const listUsersQuerySchema = z.object({
  page: z.coerce.number().int().min(0).default(0),
  pageSize: z.coerce.number().int().min(1).max(100).default(25),
  search: z.string().trim().optional(),
  filter: AdminUsersFilterSchema.default('all'),
  includeFake: z
    .enum(['true', 'false'])
    .optional()
    .transform((value) => value === 'true'),
});

const listUsersRoute = createRoute({
  method: 'get',
  path: '/users',
  summary: 'List all users with subscription data',
  request: {
    query: listUsersQuerySchema,
  },
  responses: {
    200: { content: { 'application/json': { schema: AdminUsersResponseSchema } }, description: 'Success' },
    401: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Unauthorized' },
    403: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Forbidden' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' },
  },
});

const updateUserSubscriptionRoute = createRoute({
  method: 'patch',
  path: '/users/{userId}/subscription',
  summary: 'Update a users subscription',
  request: {
    params: z.object({
      userId: z.string(),
    }),
    body: {
      content: {
        'application/json': {
          schema: subscriptionUpdateSchema,
        },
      },
    },
  },
  responses: {
    200: { content: { 'application/json': { schema: SuccessResponseSchema } }, description: 'Success' },
    401: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Unauthorized' },
    403: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Forbidden' },
    404: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Not found' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' },
  },
});

const updateUserCardLimitRoute = createRoute({
  method: 'patch',
  path: '/users/{userId}/card-limit',
  summary: 'Update a users card limit',
  request: {
    params: z.object({
      userId: z.string(),
    }),
    body: {
      content: {
        'application/json': {
          schema: cardLimitUpdateSchema,
        },
      },
    },
  },
  responses: {
    200: { content: { 'application/json': { schema: SuccessResponseSchema } }, description: 'Success' },
    401: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Unauthorized' },
    403: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Forbidden' },
    404: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Not found' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' },
  },
});

const subjectUsageRoute = createRoute({
  method: 'get',
  path: '/subject-usage',
  summary: 'List subject usage statistics',
  responses: {
    200: { content: { 'application/json': { schema: AdminSubjectUsageResponseSchema } }, description: 'Success' },
    401: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Unauthorized' },
    403: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Forbidden' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' },
  },
});

async function fetchAdminUsers(
  c: any,
  {
    page,
    pageSize,
    search,
    filter,
    includeFake,
  }: {
    page: number;
    pageSize: number;
    search?: string;
    filter: 'all' | 'free' | 'premium' | 'fake';
    includeFake: boolean;
  }
) {
  const whereClauses: string[] = [];
  const whereBindings: unknown[] = [];
  const normalizedSearch = search?.trim().toLowerCase();

  if (normalizedSearch) {
    const searchPattern = `%${normalizedSearch}%`;
    whereClauses.push(`
      (
        LOWER(COALESCE(p.username, '')) LIKE ?
        OR LOWER(COALESCE(p.email, '')) LIKE ?
      )
    `);
    whereBindings.push(searchPattern, searchPattern);
  }

  if (filter === 'fake') {
    whereClauses.push(`LOWER(COALESCE(p.email, '')) LIKE 'fake_%'`);
  } else {
    if (!includeFake) {
      whereClauses.push(`LOWER(COALESCE(p.email, '')) NOT LIKE 'fake_%'`);
    }

    if (filter === 'premium') {
      whereClauses.push(`
        (
          p.is_premium = 1
          OR (
            us.status = 'active'
            AND (
              us.expiry_date IS NULL
              OR us.expiry_date = ''
              OR datetime(us.expiry_date) > CURRENT_TIMESTAMP
            )
          )
        )
      `);
    } else if (filter === 'free') {
      whereClauses.push(`
        (
          p.is_premium != 1
          AND (
            us.status IS NULL
            OR us.status != 'active'
            OR (
              us.expiry_date IS NOT NULL
              AND us.expiry_date != ''
              AND datetime(us.expiry_date) <= CURRENT_TIMESTAMP
            )
          )
        )
      `);
    }
  }

  const whereSql =
    whereClauses.length > 0 ? `WHERE ${whereClauses.join(' AND ')}` : '';
  const offset = page * pageSize;

  const countResult = await c.env.DB.prepare(`
    SELECT COUNT(*) AS count
    FROM profiles p
    LEFT JOIN user_subscriptions us ON us.user_id = p.id
    ${whereSql}
  `).bind(...whereBindings).first<{ count: number | string | null }>();

  const overallResult = await c.env.DB.prepare(`
    SELECT COUNT(*) AS count
    FROM profiles
  `).first<{ count: number | string | null }>();

  const { results } = await c.env.DB.prepare(`
    SELECT
      p.*,
      us.id AS subscription_id,
      us.user_id AS subscription_user_id,
      us.status AS subscription_status,
      us.provider AS subscription_provider,
      us.expiry_date AS subscription_expiry_date,
      us.purchase_token AS subscription_purchase_token,
      us.order_id AS subscription_order_id,
      us.product_id AS subscription_product_id,
      us.created_at AS subscription_created_at,
      us.updated_at AS subscription_updated_at
    FROM profiles p
    LEFT JOIN user_subscriptions us ON us.user_id = p.id
    ${whereSql}
    ORDER BY COALESCE(NULLIF(p.username, ''), p.email) COLLATE NOCASE
    LIMIT ? OFFSET ?
  `).bind(...whereBindings, pageSize, offset).all();

  const users = (results as any[]).map((row) => {
    const subscriptionId = row.subscription_id ?? null;
    const subscription = subscriptionId
      ? {
          id: subscriptionId,
          user_id: row.subscription_user_id ?? null,
          status: row.subscription_status ?? null,
          provider: row.subscription_provider ?? null,
          expiry_date: row.subscription_expiry_date ?? null,
          purchase_token: row.subscription_purchase_token ?? null,
          order_id: row.subscription_order_id ?? null,
          product_id: row.subscription_product_id ?? null,
          created_at: row.subscription_created_at ?? null,
          updated_at: row.subscription_updated_at ?? null,
        }
      : null;

    const {
      subscription_id,
      subscription_user_id,
      subscription_status,
      subscription_provider,
      subscription_expiry_date,
      subscription_purchase_token,
      subscription_order_id,
      subscription_product_id,
      subscription_created_at,
      subscription_updated_at,
      ...profile
    } = row;

    return {
      ...profile,
      subscription,
    };
  });

  const totalCount = Number(countResult?.count ?? 0);
  const overallCount = Number(overallResult?.count ?? 0);

  return {
    users,
    page,
    pageSize,
    totalCount,
    totalPages: totalCount == 0 ? 0 : Math.ceil(totalCount / pageSize),
    overallCount,
  };
}

router.openapi(listUsersRoute, async (c) => {
  const user = c.get('user');
  if (!user) return c.json({ error: 'Unauthorized' } as any, 401);
  if (user.id !== ADMIN_ID) return c.json({ error: 'Forbidden' } as any, 403);

  try {
    const query = c.req.valid('query');
    const users = await fetchAdminUsers(c, {
      page: query.page,
      pageSize: query.pageSize,
      search: query.search,
      filter: query.filter,
      includeFake: query.includeFake,
    });
    return c.json(users as any, 200);
  } catch (e: any) {
    return c.json({ error: e.message } as any, 500);
  }
});

router.openapi(subjectUsageRoute, async (c) => {
  const user = c.get('user');
  if (!user) return c.json({ error: 'Unauthorized' } as any, 401);
  if (user.id !== ADMIN_ID) return c.json({ error: 'Forbidden' } as any, 403);

  try {
    const { results } = await c.env.DB.prepare(`
      SELECT
        s.id AS subject_id,
        COALESCE(NULLIF(s.name, ''), s.id) AS subject_name,
        p.name AS pillar_name,
        f.name AS folder_name,
        COALESCE(SUM(sus.started_count), 0) AS total_started,
        COALESCE(SUM(sus.completed_count), 0) AS total_completed,
        COALESCE(SUM(CASE WHEN sus.mode = 'learn' THEN sus.started_count ELSE 0 END), 0) AS learn_started,
        COALESCE(SUM(CASE WHEN sus.mode = 'learn' THEN sus.completed_count ELSE 0 END), 0) AS learn_completed,
        COALESCE(SUM(CASE WHEN sus.mode = 'test' THEN sus.started_count ELSE 0 END), 0) AS test_started,
        COALESCE(SUM(CASE WHEN sus.mode = 'test' THEN sus.completed_count ELSE 0 END), 0) AS test_completed,
        MAX(sus.updated_at) AS updated_at
      FROM subject_usage_stats sus
      INNER JOIN subjects s ON s.id = sus.subject_id
      LEFT JOIN pillars p ON p.id = s.pillar_id
      LEFT JOIN folders f ON f.id = s.folder_id
      GROUP BY s.id
      ORDER BY total_started DESC, total_completed DESC, subject_name COLLATE NOCASE
      LIMIT 200
    `).all();

    const rows = (results as any[]).map((row) => {
      const totalStarted = Number(row.total_started ?? 0);
      const totalCompleted = Number(row.total_completed ?? 0);
      return {
        subject_id: row.subject_id,
        subject_name: row.subject_name,
        pillar_name: row.pillar_name ?? null,
        folder_name: row.folder_name ?? null,
        total_started: totalStarted,
        total_completed: totalCompleted,
        learn_started: Number(row.learn_started ?? 0),
        learn_completed: Number(row.learn_completed ?? 0),
        test_started: Number(row.test_started ?? 0),
        test_completed: Number(row.test_completed ?? 0),
        completion_rate: totalStarted > 0 ? totalCompleted / totalStarted : 0,
        updated_at: row.updated_at ?? null,
      };
    });

    return c.json(rows as any, 200);
  } catch (e: any) {
    return c.json({ error: e.message } as any, 500);
  }
});

router.openapi(updateUserSubscriptionRoute, async (c) => {
  const user = c.get('user');
  if (!user) return c.json({ error: 'Unauthorized' } as any, 401);
  if (user.id !== ADMIN_ID) return c.json({ error: 'Forbidden' } as any, 403);

  try {
    const { userId } = c.req.valid('param');
    const rawBody = await c.req.json().catch(() => ({}));
    const body = subscriptionUpdateSchema.parse(rawBody);

    const profile = await c.env.DB.prepare(
      'SELECT id FROM profiles WHERE id = ?'
    ).bind(userId).first();

    if (!profile) {
      return c.json({ error: 'User not found' } as any, 404);
    }

    const expiryDate =
      body.expiry_date === undefined || body.expiry_date === null || body.expiry_date === ''
        ? null
        : body.expiry_date;

    await c.env.DB.prepare(`
      INSERT INTO user_subscriptions (
        id,
        user_id,
        status,
        provider,
        expiry_date,
        created_at,
        updated_at
      ) VALUES (?, ?, ?, 'aliolo', ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ON CONFLICT(user_id) DO UPDATE SET
        status = excluded.status,
        provider = 'aliolo',
        expiry_date = excluded.expiry_date,
        updated_at = CURRENT_TIMESTAMP
    `).bind(generateId(15), userId, body.status, expiryDate).run();

    return c.json({ success: true } as any, 200);
  } catch (e: any) {
    console.error('Admin subscription update failed:', e);
    return c.json({ error: e.message } as any, 500);
  }
});

router.openapi(updateUserCardLimitRoute, async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Unauthorized' } as any, 401);
    if (user.id !== ADMIN_ID) return c.json({ error: 'Forbidden' } as any, 403);
  
    try {
      const { userId } = c.req.valid('param');
      const { card_limit } = c.req.valid('json');
  
      const profile = await c.env.DB.prepare(
        'SELECT id FROM profiles WHERE id = ?'
      ).bind(userId).first();
  
      if (!profile) {
        return c.json({ error: 'User not found' } as any, 404);
      }
  
      await c.env.DB.prepare(
        'UPDATE profiles SET card_limit = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?'
      ).bind(card_limit, userId).run();
  
      return c.json({ success: true } as any, 200);
    } catch (e: any) {
      console.error('Admin card limit update failed:', e);
      return c.json({ error: e.message } as any, 500);
    }
  });

export default router;
