import { z } from '@hono/zod-openapi';

export const CardSchema = z.object({
  id: z.string().openapi({ example: 'card_123' }),
  subject_id: z.string().openapi({ example: 'subj_456' }),
  owner_id: z.string().nullable().openapi({ example: 'user_789' }),
  level: z.number().openapi({ example: 1 }),
  test_mode: z.string().openapi({ example: 'standard' }),
  is_public: z.number().openapi({ example: 1 }),
  is_deleted: z.number().openapi({ example: 0 }),
  localized_data: z.string().openapi({ description: 'JSON string' }),
  created_at: z.string().openapi({ example: '2026-04-12T00:00:00Z' }),
  updated_at: z.string().openapi({ example: '2026-04-12T00:00:00Z' }),
}).openapi('Card');

export const CardsResponseSchema = z.array(CardSchema);

export const CreateCardSchema = z.object({
  id: z.string().openapi({ example: 'card_123' }),
  subject_id: z.string().openapi({ example: 'subj_456' }),
  level: z.number().optional().openapi({ example: 1 }),
  test_mode: z.string().optional().openapi({ example: 'standard' }),
  is_public: z.boolean().optional().openapi({ example: true }),
  localized_data: z.record(z.any()).openapi({ 
    example: { global: { answer: 'A', prompt: 'Choose A' } } 
  }),
}).openapi('CreateCard');
