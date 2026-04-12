import { z } from '@hono/zod-openapi';

export const ProgressUpdateSchema = z.object({
  card_id: z.string().openapi({ example: 'card_123' }),
  subject_id: z.string().optional().openapi({ example: 'subj_456' }),
  correct_count: z.number().optional().openapi({ example: 5 }),
  is_hidden: z.boolean().optional().openapi({ example: true }),
}).openapi('ProgressUpdate');

export const ProgressSchema = z.object({
  id: z.number().openapi({ example: 1 }),
  user_id: z.string().openapi({ example: 'user_789' }),
  card_id: z.string().openapi({ example: 'card_123' }),
  subject_id: z.string().nullable().openapi({ example: 'subj_456' }),
  correct_count: z.number().openapi({ example: 5 }),
  repetition_count: z.number().openapi({ example: 10 }),
  interval: z.number().openapi({ example: 1 }),
  ease_factor: z.number().openapi({ example: 2.5 }),
  next_review: z.string().nullable().openapi({ example: '2026-04-12T00:00:00Z' }),
  is_hidden: z.number().openapi({ example: 0 }),
  created_at: z.string().openapi({ example: '2026-04-12T00:00:00Z' }),
  updated_at: z.string().openapi({ example: '2026-04-12T00:00:00Z' }),
}).openapi('Progress');
