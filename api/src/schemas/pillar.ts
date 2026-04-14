import { z } from '@hono/zod-openapi';

export const PillarSchema = z.object({
  id: z.number().openapi({ example: 1 }),
  sort_order: z.number().openapi({ example: 1 }),
  light_color: z.string().openapi({ example: '#ffffff' }),
  dark_color: z.string().openapi({ example: '#000000' }),
  icon: z.string().openapi({ example: 'home' }),
  name: z.string().openapi({ example: 'World' }),
  names: z.string().openapi({ 
    description: 'JSON string containing localized names',
    example: '{"es": "Mundo"}' 
  }),
  description: z.string().openapi({ example: 'Geography, maps and countries.' }),
  descriptions: z.string().openapi({ 
    description: 'JSON string containing localized descriptions',
    example: '{"es": "Geografía, mapas y países."}' 
  }),
  subject_count: z.number().openapi({ example: 42 }),
  folder_count: z.number().openapi({ example: 5 }),
}).openapi('Pillar');

export const PillarsResponseSchema = z.array(PillarSchema);
