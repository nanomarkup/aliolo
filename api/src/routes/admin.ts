import { OpenAPIHono, createRoute, z } from '@hono/zod-openapi';
import { generateId } from 'lucia';
import type { AppEnv } from '../types';
import { AdminUsersResponseSchema } from '../schemas/admin';
import { ErrorResponseSchema, SuccessResponseSchema } from '../schemas/shared';

const router = new OpenAPIHono<AppEnv>();
const ADMIN_ID = 'usyeo7d2yzf2773';

const subscriptionUpdateSchema = z.object({
  status: z.enum(['active', 'inactive']),
  expiry_date: z.string().nullable().optional(),
});

const listUsersRoute = createRoute({
  method: 'get',
  path: '/users',
  summary: 'List all users with subscription data',
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

async function fetchAdminUsers(c: any) {
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
    ORDER BY COALESCE(NULLIF(p.username, ''), p.email) COLLATE NOCASE
  `).all();

  return (results as any[]).map((row) => {
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
}

router.openapi(listUsersRoute, async (c) => {
  const user = c.get('user');
  if (!user) return c.json({ error: 'Unauthorized' } as any, 401);
  if (user.id !== ADMIN_ID) return c.json({ error: 'Forbidden' } as any, 403);

  try {
    const users = await fetchAdminUsers(c);
    return c.json(users as any, 200);
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

    await c.env.DB.prepare(`
      UPDATE profiles
      SET is_premium = CASE WHEN ? = 'active' THEN 1 ELSE 0 END,
          updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `).bind(body.status, userId).run();

    return c.json({ success: true } as any, 200);
  } catch (e: any) {
    console.error('Admin subscription update failed:', e);
    return c.json({ error: e.message } as any, 500);
  }
});

export default router;
