import { z } from '@hono/zod-openapi';

export const LanguageSchema = z.object({
  id: z.string().openapi({ example: 'en' }),
  name: z.string().openapi({ example: 'English' }),
});

export const LanguagesResponseSchema = z.array(LanguageSchema);

export const TranslationsResponseSchema = z.record(z.string(), z.string()).openapi({
  example: {
    'app.title': 'Aliolo',
    'app.welcome': 'Welcome to Aliolo',
  },
});
