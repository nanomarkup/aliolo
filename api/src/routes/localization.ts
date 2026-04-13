import { OpenAPIHono, createRoute, z } from '@hono/zod-openapi';
import type { AppEnv } from '../types';
import { LanguagesResponseSchema, TranslationsResponseSchema } from '../schemas/localization';
import { ErrorResponseSchema } from '../schemas/shared';

const router = new OpenAPIHono<AppEnv>();

const listLanguagesRoute = createRoute({
  method: 'get',
  path: '/languages',
  summary: 'List languages',
  responses: {
    200: { content: { 'application/json': { schema: LanguagesResponseSchema } }, description: 'Success' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(listLanguagesRoute, async (c) => {
    try {
        const { results } = await c.env.DB.prepare(
            'SELECT id, name FROM languages ORDER BY name'
        ).all();
        return c.json(results as any, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

const getTranslationsRoute = createRoute({
  method: 'get',
  path: '/translations/{lang}',
  summary: 'Get translations for a language',
  request: {
    params: z.object({
      lang: z.string().openapi({ description: 'Language code' }),
    }),
  },
  responses: {
    200: { content: { 'application/json': { schema: TranslationsResponseSchema } }, description: 'Success' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(getTranslationsRoute, async (c) => {
    const { lang } = c.req.valid('param');
    try {
        const { results } = await c.env.DB.prepare(
            'SELECT key, value FROM ui_translations WHERE lang = ?'
        ).bind(lang).all();
        
        const map: Record<string, string> = {};
        results.forEach((r: any) => {
            map[r.key] = r.value;
        });
        return c.json(map as any, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

export default router;
