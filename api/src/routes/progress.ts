import { OpenAPIHono, createRoute, z } from '@hono/zod-openapi';
import type { AppEnv } from '../types';
import {
    ProgressReviewSchema,
    ProgressReviewSessionResponseSchema,
    ProgressReviewSessionSchema,
    ProgressUpdateSchema,
    ProgressSchema,
} from '../schemas/progress';
import { SuccessResponseSchema, ErrorResponseSchema } from '../schemas/shared';

const router = new OpenAPIHono<AppEnv>();

function addDays(date: Date, days: number): string {
    const next = new Date(date.getTime());
    next.setUTCDate(next.getUTCDate() + days);
    return next.toISOString();
}

function calculateSm2({
    quality,
    repetitionCount,
    interval,
    easeFactor,
}: {
    quality: number;
    repetitionCount: number;
    interval: number;
    easeFactor: number;
}) {
    const difficulty = 5 - quality;
    const nextEaseFactor = Math.max(
        1.3,
        easeFactor + (0.1 - difficulty * (0.08 + difficulty * 0.02))
    );

    if (quality < 3) {
        return {
            repetitionCount: 0,
            interval: 1,
            easeFactor: nextEaseFactor,
        };
    }

    if (repetitionCount <= 0) {
        return {
            repetitionCount: 1,
            interval: 1,
            easeFactor: nextEaseFactor,
        };
    }

    if (repetitionCount === 1) {
        return {
            repetitionCount: 2,
            interval: 6,
            easeFactor: nextEaseFactor,
        };
    }

    return {
        repetitionCount: repetitionCount + 1,
        interval: Math.max(1, Math.round(interval * nextEaseFactor)),
        easeFactor: nextEaseFactor,
    };
}

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

const reviewSessionRoute = createRoute({
  method: 'post',
  path: '/review-session',
  summary: 'Select cards for an SM-2 review session',
  request: {
    body: { content: { 'application/json': { schema: ProgressReviewSessionSchema } } }
  },
  responses: {
    200: { content: { 'application/json': { schema: ProgressReviewSessionResponseSchema } }, description: 'Success' },
    401: { description: 'Unauthorized' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(reviewSessionRoute, async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' } as any, 401);

    const { card_ids, limit } = c.req.valid('json');
    const uniqueCardIds = [...new Set(card_ids)].filter((id) => id.trim().length > 0);
    if (uniqueCardIds.length === 0) return c.json({ card_ids: [] }, 200);

    try {
        const progressRows: any[] = [];
        const chunkSize = 900;
        for (let i = 0; i < uniqueCardIds.length; i += chunkSize) {
            const chunk = uniqueCardIds.slice(i, i + chunkSize);
            const placeholders = chunk.map(() => '?').join(',');
            const { results } = await c.env.DB.prepare(`
                SELECT card_id, is_hidden, next_review
                FROM progress
                WHERE user_id = ? AND card_id IN (${placeholders})
            `).bind(user.id, ...chunk).all();
            progressRows.push(...(results as any[]));
        }

        const progressByCardId = new Map<string, any>(
            progressRows.map((row) => [row.card_id, row])
        );
        const now = Date.now();
        const dueCards: { id: string; nextReviewTime: number }[] = [];
        const newCards: string[] = [];

        for (const id of uniqueCardIds) {
            const progress = progressByCardId.get(id);
            if (!progress) {
                newCards.push(id);
                continue;
            }

            if (progress.is_hidden === 1) continue;

            const nextReview = progress.next_review;
            if (!nextReview) {
                dueCards.push({ id, nextReviewTime: 0 });
                continue;
            }

            const nextReviewTime = Date.parse(nextReview);
            if (Number.isNaN(nextReviewTime) || nextReviewTime <= now) {
                dueCards.push({ id, nextReviewTime: Number.isNaN(nextReviewTime) ? 0 : nextReviewTime });
            }
        }

        dueCards.sort((a, b) => a.nextReviewTime - b.nextReviewTime);
        const selected = [
            ...dueCards.map((card) => card.id),
            ...newCards,
        ].slice(0, limit);

        return c.json({ card_ids: selected }, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

const reviewProgressRoute = createRoute({
  method: 'post',
  path: '/review',
  summary: 'Record an SM-2 review answer',
  request: {
    body: { content: { 'application/json': { schema: ProgressReviewSchema } } }
  },
  responses: {
    200: { content: { 'application/json': { schema: SuccessResponseSchema } }, description: 'Success' },
    401: { description: 'Unauthorized' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(reviewProgressRoute, async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' } as any, 401);

    const { card_id, subject_id, quality } = c.req.valid('json');

    try {
        const existing: any = await c.env.DB.prepare(
            "SELECT * FROM progress WHERE user_id = ? AND card_id = ?"
        ).bind(user.id, card_id).first();

        const previousCorrectCount = Number(existing?.correct_count ?? 0);
        const previousRepetitionCount = Number(existing?.repetition_count ?? 0);
        const previousInterval = Number(existing?.interval ?? 0);
        const previousEaseFactor = Number(existing?.ease_factor ?? 2.5);
        const next = calculateSm2({
            quality,
            repetitionCount: previousRepetitionCount,
            interval: previousInterval,
            easeFactor: previousEaseFactor,
        });
        const correctCount = quality >= 3 ? previousCorrectCount + 1 : previousCorrectCount;
        const nextReview = addDays(new Date(), next.interval);

        await c.env.DB.prepare(`
            INSERT INTO progress (
                user_id,
                card_id,
                subject_id,
                correct_count,
                repetition_count,
                interval,
                ease_factor,
                next_review,
                is_hidden,
                updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, CURRENT_TIMESTAMP)
            ON CONFLICT(user_id, card_id) DO UPDATE SET
                subject_id = COALESCE(excluded.subject_id, progress.subject_id),
                correct_count = excluded.correct_count,
                repetition_count = excluded.repetition_count,
                interval = excluded.interval,
                ease_factor = excluded.ease_factor,
                next_review = excluded.next_review,
                updated_at = CURRENT_TIMESTAMP
        `).bind(
            user.id,
            card_id,
            subject_id || existing?.subject_id || null,
            correctCount,
            next.repetitionCount,
            next.interval,
            next.easeFactor,
            nextReview
        ).run();

        return c.json({ success: true }, 200);
    } catch (e: any) {
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
