import { OpenAPIHono, createRoute } from '@hono/zod-openapi';
import type { AppEnv } from '../types';
import { LanguagesResponseSchema } from '../schemas/localization';
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

export default router;

