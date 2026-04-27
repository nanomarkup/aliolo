import { OpenAPIHono, createRoute, z } from '@hono/zod-openapi';
import { generateId } from 'lucia';
import type { AppEnv } from '../types';
import {
  AdminOnboardingAnalyticsResponseSchema,
  AdminSubjectUsageResponseSchema,
  AdminUsersFilterSchema,
  AdminUsersResponseSchema,
} from '../schemas/admin';
import { ErrorResponseSchema, SuccessResponseSchema } from '../schemas/shared';
import { recomputeUserSubscription } from '../utils/subscriptions';

const router = new OpenAPIHono<AppEnv>();
const ADMIN_ID = 'usyeo7d2yzf2773';

const subscriptionUpdateSchema = z.object({
  status: z.enum(['active', 'inactive']),
  expiry_date: z.string().nullable().optional(),
  reason: z.string().trim().optional(),
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

const onboardingAnalyticsRoute = createRoute({
  method: 'get',
  path: '/onboarding-analytics',
  summary: 'List onboarding analytics statistics',
  responses: {
    200: { content: { 'application/json': { schema: AdminOnboardingAnalyticsResponseSchema } }, description: 'Success' },
    401: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Unauthorized' },
    403: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Forbidden' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' },
  },
});

async function getTableColumns(c: any, tableName: string): Promise<Set<string>> {
  const { results } = await c.env.DB.prepare(`PRAGMA table_info(${tableName})`).all();
  return new Set(
    (results as any[])
      .map((row) => row.name?.toString())
      .filter((name): name is string => Boolean(name)),
  );
}

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
  const activeSubscriptionSql = `(ap.id IS NOT NULL OR am.id IS NOT NULL)`;
  const manualWinsSql = `(
    am.id IS NOT NULL
    AND (
      ap.id IS NULL
      OR am.ends_at IS NULL
      OR (
        ap.current_period_end IS NOT NULL
        AND datetime(am.ends_at) > datetime(ap.current_period_end)
      )
    )
  )`;
  const subscriptionCtes = `
    WITH active_provider AS (
      SELECT *
      FROM (
        SELECT
          ps.*,
          ROW_NUMBER() OVER (
            PARTITION BY ps.user_id
            ORDER BY
              CASE WHEN ps.current_period_end IS NULL THEN 1 ELSE 0 END DESC,
              datetime(ps.current_period_end) DESC
          ) AS rn
        FROM provider_subscriptions ps
        WHERE ps.status IN ('active', 'trialing')
          AND (ps.current_period_end IS NULL OR datetime(ps.current_period_end) > CURRENT_TIMESTAMP)
      )
      WHERE rn = 1
    ),
    active_manual AS (
      SELECT *
      FROM (
        SELECT
          msg.*,
          ROW_NUMBER() OVER (
            PARTITION BY msg.user_id
            ORDER BY
              CASE WHEN msg.ends_at IS NULL THEN 1 ELSE 0 END DESC,
              datetime(msg.ends_at) DESC
          ) AS rn
        FROM manual_subscription_grants msg
        WHERE msg.status = 'active'
          AND (msg.starts_at IS NULL OR datetime(msg.starts_at) <= CURRENT_TIMESTAMP)
          AND (msg.ends_at IS NULL OR datetime(msg.ends_at) > CURRENT_TIMESTAMP)
      )
      WHERE rn = 1
    )
  `;

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
          OR ${activeSubscriptionSql}
        )
      `);
    } else if (filter === 'free') {
      whereClauses.push(`
        (
          p.is_premium != 1
          AND NOT ${activeSubscriptionSql}
        )
      `);
    }
  }

  const whereSql =
    whereClauses.length > 0 ? `WHERE ${whereClauses.join(' AND ')}` : '';
  const offset = page * pageSize;

  const countResult = await c.env.DB.prepare(`
    ${subscriptionCtes}
    SELECT COUNT(*) AS count
    FROM profiles p
    LEFT JOIN active_provider ap ON ap.user_id = p.id
    LEFT JOIN active_manual am ON am.user_id = p.id
    ${whereSql}
  `).bind(...whereBindings).first<{ count: number | string | null }>();

  const overallResult = await c.env.DB.prepare(`
    SELECT COUNT(*) AS count
    FROM profiles
  `).first<{ count: number | string | null }>();

  const { results } = await c.env.DB.prepare(`
    ${subscriptionCtes}
    SELECT
      p.*,
      CASE
        WHEN ${manualWinsSql} THEN am.id
        WHEN ap.id IS NOT NULL THEN ap.id
        WHEN am.id IS NOT NULL THEN am.id
        ELSE NULL
      END AS subscription_id,
      CASE WHEN ${activeSubscriptionSql} THEN p.id ELSE NULL END AS subscription_user_id,
      CASE WHEN ${activeSubscriptionSql} THEN 'active' ELSE NULL END AS subscription_status,
      CASE
        WHEN ${manualWinsSql} THEN 'aliolo_manual'
        WHEN ap.id IS NOT NULL THEN ap.provider
        WHEN am.id IS NOT NULL THEN 'aliolo_manual'
        ELSE NULL
      END AS subscription_provider,
      CASE
        WHEN ${manualWinsSql} THEN 'manual'
        WHEN ap.id IS NOT NULL THEN 'provider'
        WHEN am.id IS NOT NULL THEN 'manual'
        ELSE NULL
      END AS subscription_effective_source,
      CASE
        WHEN ap.id IS NOT NULL AND am.id IS NOT NULL THEN
          CASE
            WHEN ap.current_period_end IS NULL OR am.ends_at IS NULL THEN NULL
            WHEN datetime(ap.current_period_end) >= datetime(am.ends_at) THEN ap.current_period_end
            ELSE am.ends_at
          END
        WHEN ap.id IS NOT NULL THEN ap.current_period_end
        WHEN am.id IS NOT NULL THEN am.ends_at
        ELSE NULL
      END AS subscription_expiry_date,
      CASE WHEN ${manualWinsSql} THEN NULL ELSE ap.product_id END AS subscription_product_id,
      ap.id AS subscription_active_provider_subscription_id,
      am.id AS subscription_active_manual_grant_id,
      CASE
        WHEN ${manualWinsSql} THEN am.created_at
        WHEN ap.id IS NOT NULL THEN ap.created_at
        WHEN am.id IS NOT NULL THEN am.created_at
        ELSE NULL
      END AS subscription_created_at,
      CASE
        WHEN ${manualWinsSql} THEN am.updated_at
        WHEN ap.id IS NOT NULL THEN ap.updated_at
        WHEN am.id IS NOT NULL THEN am.updated_at
        ELSE NULL
      END AS subscription_updated_at
    FROM profiles p
    LEFT JOIN active_provider ap ON ap.user_id = p.id
    LEFT JOIN active_manual am ON am.user_id = p.id
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
          effective_source: row.subscription_effective_source ?? null,
          expiry_date: row.subscription_expiry_date ?? null,
          purchase_token: null,
          order_id: null,
          product_id: row.subscription_product_id ?? null,
          active_provider_subscription_id: row.subscription_active_provider_subscription_id ?? null,
          active_manual_grant_id: row.subscription_active_manual_grant_id ?? null,
          created_at: row.subscription_created_at ?? null,
          updated_at: row.subscription_updated_at ?? null,
        }
      : null;

    const {
      subscription_id,
      subscription_user_id,
      subscription_status,
      subscription_provider,
      subscription_effective_source,
      subscription_expiry_date,
      subscription_product_id,
      subscription_active_provider_subscription_id,
      subscription_active_manual_grant_id,
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
    const period = c.req.query('period') || 'all';
    const subjectUsageColumns = await getTableColumns(c, 'subject_usage_stats');
    const hasAggregateSubjectUsage = subjectUsageColumns.has('started_count');
    const totalStartedExpr = hasAggregateSubjectUsage
      ? 'SUM(sus.started_count)'
      : 'COUNT(sus.id)';
    const totalCompletedExpr = hasAggregateSubjectUsage
      ? 'SUM(sus.completed_count)'
      : 'SUM(CASE WHEN sus.completed = 1 THEN 1 ELSE 0 END)';
    const learnStartedExpr = hasAggregateSubjectUsage
      ? "SUM(CASE WHEN sus.mode = 'learn' THEN sus.started_count ELSE 0 END)"
      : "SUM(CASE WHEN sus.mode = 'learn' THEN 1 ELSE 0 END)";
    const learnCompletedExpr = hasAggregateSubjectUsage
      ? "SUM(CASE WHEN sus.mode = 'learn' THEN sus.completed_count ELSE 0 END)"
      : "SUM(CASE WHEN sus.mode = 'learn' AND sus.completed = 1 THEN 1 ELSE 0 END)";
    const testStartedExpr = hasAggregateSubjectUsage
      ? "SUM(CASE WHEN sus.mode = 'test' THEN sus.started_count ELSE 0 END)"
      : "SUM(CASE WHEN sus.mode = 'test' THEN 1 ELSE 0 END)";
    const testCompletedExpr = hasAggregateSubjectUsage
      ? "SUM(CASE WHEN sus.mode = 'test' THEN sus.completed_count ELSE 0 END)"
      : "SUM(CASE WHEN sus.mode = 'test' AND sus.completed = 1 THEN 1 ELSE 0 END)";

    let dateFilter = '';
    if (period === '1m') {
      dateFilter = "AND sus.created_at >= datetime('now', '-1 month')";
    } else if (period === '3m') {
      dateFilter = "AND sus.created_at >= datetime('now', '-3 month')";
    } else if (period === '6m') {
      dateFilter = "AND sus.created_at >= datetime('now', '-6 month')";
    }

    const { results } = await c.env.DB.prepare(`
      SELECT
        s.id AS subject_id,
        COALESCE(NULLIF(s.name, ''), s.id) AS subject_name,
        p.name AS pillar_name,
        f.name AS folder_name,
        ${totalStartedExpr} AS total_started,
        ${totalCompletedExpr} AS total_completed,
        ${learnStartedExpr} AS learn_started,
        ${learnCompletedExpr} AS learn_completed,
        ${testStartedExpr} AS test_started,
        ${testCompletedExpr} AS test_completed,
        MAX(sus.created_at) AS updated_at
      FROM subject_usage_stats sus
      INNER JOIN subjects s ON s.id = sus.subject_id
      LEFT JOIN pillars p ON p.id = s.pillar_id
      LEFT JOIN folders f ON f.id = s.folder_id
      WHERE 1=1 ${dateFilter}
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

router.openapi(onboardingAnalyticsRoute, async (c) => {
  const user = c.get('user');
  if (!user) return c.json({ error: 'Unauthorized' } as any, 401);
  if (user.id !== ADMIN_ID) return c.json({ error: 'Forbidden' } as any, 403);

  try {
    const summaryResult = await c.env.DB.prepare(`
      SELECT
        COUNT(*) AS total_sessions,
        SUM(CASE WHEN COALESCE(TRIM(user_email), '') != '' THEN 1 ELSE 0 END) AS linked_email_sessions,
        SUM(CASE WHEN COALESCE(TRIM(age_range), '') != '' THEN 1 ELSE 0 END) AS age_selected_sessions,
        SUM(CASE WHEN pillar_id IS NOT NULL THEN 1 ELSE 0 END) AS pillar_selected_sessions,
        SUM(CASE WHEN last_slide_index IS NOT NULL THEN 1 ELSE 0 END) AS slide_recorded_sessions,
        SUM(CASE WHEN last_slide_index = 6 THEN 1 ELSE 0 END) AS final_slide_sessions,
        COUNT(DISTINCT CASE WHEN COALESCE(TRIM(user_email), '') != '' THEN LOWER(TRIM(user_email)) END) AS unique_emails,
        AVG(last_slide_index) AS average_last_slide_index,
        MAX(updated_at) AS latest_updated_at
      FROM onboarding_analytics
    `).first<any>();

    const ageBreakdownResult = await c.env.DB.prepare(`
      SELECT
        COALESCE(NULLIF(age_range, ''), 'not_set') AS age_range,
        COUNT(*) AS sessions
      FROM onboarding_analytics
      GROUP BY COALESCE(NULLIF(age_range, ''), 'not_set')
      ORDER BY sessions DESC, age_range COLLATE NOCASE
    `).all();

    const pillarBreakdownResult = await c.env.DB.prepare(`
      SELECT
        oa.pillar_id AS pillar_id,
        COALESCE(p.name, 'Not set') AS pillar_name,
        COUNT(*) AS sessions
      FROM onboarding_analytics oa
      LEFT JOIN pillars p ON p.id = oa.pillar_id
      GROUP BY oa.pillar_id, COALESCE(p.name, 'Not set')
      ORDER BY sessions DESC, pillar_name COLLATE NOCASE
    `).all();

    const slideBreakdownResult = await c.env.DB.prepare(`
      SELECT
        last_slide_index,
        COUNT(*) AS sessions
      FROM onboarding_analytics
      GROUP BY last_slide_index
      ORDER BY COALESCE(last_slide_index, -1) ASC
    `).all();

    const { results } = await c.env.DB.prepare(`
      SELECT
        oa.session_id,
        oa.user_email,
        oa.age_range,
        oa.pillar_id,
        COALESCE(p.name, NULL) AS pillar_name,
        oa.last_slide_index,
        oa.created_at,
        oa.updated_at
      FROM onboarding_analytics oa
      LEFT JOIN pillars p ON p.id = oa.pillar_id
      ORDER BY oa.updated_at DESC, oa.created_at DESC
      LIMIT 200
    `).all();

    const totalSessions = Number(summaryResult?.total_sessions ?? 0);
    const finalSlideSessions = Number(summaryResult?.final_slide_sessions ?? 0);
    const averageLastSlideIndexRaw = summaryResult?.average_last_slide_index;
    const averageLastSlideIndex =
      averageLastSlideIndexRaw === null || averageLastSlideIndexRaw === undefined
        ? null
        : Number(averageLastSlideIndexRaw);

    return c.json({
      summary: {
        total_sessions: totalSessions,
        linked_email_sessions: Number(summaryResult?.linked_email_sessions ?? 0),
        age_selected_sessions: Number(summaryResult?.age_selected_sessions ?? 0),
        pillar_selected_sessions: Number(summaryResult?.pillar_selected_sessions ?? 0),
        final_slide_sessions: finalSlideSessions,
        unique_emails: Number(summaryResult?.unique_emails ?? 0),
        average_last_slide_index: averageLastSlideIndex,
        completion_rate: totalSessions > 0 ? finalSlideSessions / totalSessions : 0,
        final_slide_index: 6,
        latest_updated_at: summaryResult?.latest_updated_at ?? null,
      },
      age_breakdown: (ageBreakdownResult.results as any[]).map((row) => ({
        age_range: row.age_range ?? 'not_set',
        sessions: Number(row.sessions ?? 0),
      })),
      pillar_breakdown: (pillarBreakdownResult.results as any[]).map((row) => ({
        pillar_id: row.pillar_id ?? null,
        pillar_name: row.pillar_name ?? 'Not set',
        sessions: Number(row.sessions ?? 0),
      })),
      slide_breakdown: (slideBreakdownResult.results as any[]).map((row) => ({
        last_slide_index:
          row.last_slide_index === null || row.last_slide_index === undefined
            ? null
            : Number(row.last_slide_index),
        sessions: Number(row.sessions ?? 0),
      })),
      recent_sessions: (results as any[]).map((row) => ({
        session_id: row.session_id,
        user_email: row.user_email ?? null,
        age_range: row.age_range ?? null,
        pillar_id: row.pillar_id ?? null,
        pillar_name: row.pillar_name ?? null,
        last_slide_index:
          row.last_slide_index === null || row.last_slide_index === undefined
            ? null
            : Number(row.last_slide_index),
        created_at: row.created_at ?? null,
        updated_at: row.updated_at ?? null,
      })),
    } as any, 200);
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

    if (body.status === 'inactive') {
      await c.env.DB.prepare(`
        UPDATE manual_subscription_grants
        SET status = 'inactive', updated_at = CURRENT_TIMESTAMP
        WHERE user_id = ? AND status = 'active'
      `).bind(userId).run();
    } else {
      const expiryDate =
        body.expiry_date === undefined || body.expiry_date === null || body.expiry_date === ''
          ? null
          : body.expiry_date;

      await c.env.DB.prepare(`
        INSERT INTO manual_subscription_grants (
          id,
          user_id,
          status,
          reason,
          starts_at,
          ends_at,
          created_by,
          created_at,
          updated_at
        ) VALUES (?, ?, 'active', ?, CURRENT_TIMESTAMP, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      `).bind(
        generateId(15),
        userId,
        body.reason ?? 'Admin manual subscription grant',
        expiryDate,
        user.id,
      ).run();
    }

    await recomputeUserSubscription(c.env.DB, userId);

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
