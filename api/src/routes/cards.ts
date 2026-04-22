import { OpenAPIHono, createRoute, z } from '@hono/zod-openapi';
import type { AppEnv } from '../types';
import { CardSchema, CardsResponseSchema, CreateCardSchema, CardCountSchema } from '../schemas/card';
import { SuccessResponseSchema, ErrorResponseSchema } from '../schemas/shared';

const router = new OpenAPIHono<AppEnv>();

const countCardsRoute = createRoute({
    method: 'get',
    path: '/count',
    summary: 'Get current user card count',
    responses: {
      200: { content: { 'application/json': { schema: CardCountSchema } }, description: 'Success' },
      401: { description: 'Unauthorized' },
      500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
    }
  });
  
  router.openapi(countCardsRoute, async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' } as any, 401);
  
    try {
      const result: any = await c.env.DB.prepare('SELECT count(*) as count FROM cards WHERE owner_id = ?')
        .bind(user.id)
        .first();
      return c.json({ count: result?.count || 0 }, 200);
    } catch (e: any) {
      return c.json({ error: e.message } as any, 500);
    }
  });

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
    const { results } = await c.env.DB.prepare('SELECT * FROM cards WHERE subject_id = ?')
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

    const { 
        id, subject_id, level, renderer, is_public, 
        answer, answers, prompt, prompts, display_text, display_texts,
        images_base, images_local, audio, audios, video, videos 
    } = c.req.valid('json');

    try {
        // Check if card already exists
        const existing: any = await c.env.DB.prepare('SELECT owner_id FROM cards WHERE id = ?')
            .bind(id)
            .first();

        if (!existing) {
            // New card: check limit
            const profile: any = await c.env.DB.prepare('SELECT card_limit FROM profiles WHERE id = ?')
                .bind(user.id)
                .first();
            
            const limit = profile?.card_limit ?? 200;
            const countResult: any = await c.env.DB.prepare('SELECT count(*) as count FROM cards WHERE owner_id = ?')
                .bind(user.id)
                .first();
            
            const currentCount = countResult?.count || 0;
            if (currentCount >= limit) {
                return c.json({ error: `Card limit reached (${limit} cards). To increase this limit, please contact aliolo@nohainc.com.` } as any, 403);
            }
        } else if (existing.owner_id !== user.id) {
            // Card exists but owned by someone else
            return c.json({ error: 'Forbidden' } as any, 403);
        }

        await c.env.DB.prepare(`
            INSERT INTO cards (
                id, subject_id, owner_id, level, renderer, is_public, 
                answer, answers, prompt, prompts, display_text, display_texts,
                images_base, images_local, audio, audios, video, videos,
                updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(id) DO UPDATE SET
                subject_id = excluded.subject_id,
                level = excluded.level,
                renderer = excluded.renderer,
                is_public = excluded.is_public,
                answer = excluded.answer,
                answers = excluded.answers,
                prompt = excluded.prompt,
                prompts = excluded.prompts,
                display_text = excluded.display_text,
                display_texts = excluded.display_texts,
                images_base = excluded.images_base,
                images_local = excluded.images_local,
                audio = excluded.audio,
                audios = excluded.audios,
                video = excluded.video,
                videos = excluded.videos,
                updated_at = CURRENT_TIMESTAMP
        `).bind(
            id, subject_id, user.id, level || 1, renderer || 'generic', is_public ? 1 : 0,
            answer, JSON.stringify(answers), prompt, JSON.stringify(prompts),
            display_text ?? '', JSON.stringify(display_texts ?? {}),
            JSON.stringify(images_base), JSON.stringify(images_local),
            audio, JSON.stringify(audios), video, JSON.stringify(videos)
        ).run();
        
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

        await c.env.DB.prepare("DELETE FROM cards WHERE id = ?").bind(id).run();

        const prefix = `cards/${id}/`;
        let listed = await c.env.MEDIA.list({ prefix });
        let objectsToDelete = listed.objects.map((obj: any) => obj.key);
        while (objectsToDelete.length > 0) {
            await c.env.MEDIA.delete(objectsToDelete);
            if (listed.truncated) {
                listed = await c.env.MEDIA.list({ prefix, cursor: listed.cursor });
                objectsToDelete = listed.objects.map((obj: any) => obj.key);
            } else {
                break;
            }
        }

        return c.json({ success: true }, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

export default router;
