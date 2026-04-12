import { z } from '@hono/zod-openapi';

export const CollectionItemSchema = z.object({
  subject_id: z.string().openapi({ example: 'subj_123' }),
}).openapi('CollectionItem');

export const CollectionSchema = z.object({
  id: z.string().openapi({ example: 'coll_123' }),
  pillar_id: z.number().openapi({ example: 1 }),
  folder_id: z.string().nullable().openapi({ example: 'fold_456' }),
  owner_id: z.string().openapi({ example: 'user_789' }),
  owner_name: z.string().nullable().optional().openapi({ example: 'Aliolo' }),
  is_public: z.number().openapi({ example: 1 }),
  age_group: z.string().openapi({ example: 'primary' }),
  localized_data: z.string().openapi({ description: 'JSON string' }),
  created_at: z.string().openapi({ example: '2026-04-12T00:00:00Z' }),
  updated_at: z.string().openapi({ example: '2026-04-12T00:00:00Z' }),
  collection_items: z.array(CollectionItemSchema).optional(),
  is_on_dashboard: z.boolean().optional().openapi({ example: true }),
}).openapi('Collection');

export const CollectionsResponseSchema = z.array(CollectionSchema);

export const CreateCollectionSchema = z.object({
  id: z.string().openapi({ example: 'coll_123' }),
  pillar_id: z.number().openapi({ example: 1 }),
  folder_id: z.string().nullable().optional().openapi({ example: 'fold_456' }),
  is_public: z.boolean().optional().openapi({ example: true }),
  age_group: z.string().openapi({ example: 'primary' }),
  localized_data: z.record(z.any()).openapi({ 
    example: { en: { name: 'My Collection' } } 
  }),
  subject_ids: z.array(z.string()).optional().openapi({ example: ['subj_1', 'subj_2'] }),
}).openapi('CreateCollection');
