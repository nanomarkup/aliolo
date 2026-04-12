import { z } from '@hono/zod-openapi';

export const PillarSchema = z.object({
  id: z.number().openapi({ example: 1 }),
  sort_order: z.number().openapi({ example: 1 }),
  light_color: z.string().openapi({ example: '#ffffff' }),
  dark_color: z.string().openapi({ example: '#000000' }),
  icon: z.string().openapi({ example: 'home' }),
  localized_data: z.string().openapi({ 
    description: 'JSON string containing localized names and descriptions',
    example: '{"en": {"name": "World"}}' 
  }),
  subject_count: z.number().openapi({ example: 42 }),
  folder_count: z.number().openapi({ example: 5 }),
}).openapi('Pillar');

export const PillarsResponseSchema = z.array(PillarSchema);
