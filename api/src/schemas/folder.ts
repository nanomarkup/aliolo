import { z } from '@hono/zod-openapi';

export const FolderSchema = z.object({
  id: z.string().openapi({ example: 'fold_123' }),
  pillar_id: z.number().openapi({ example: 1 }),
  owner_id: z.string().openapi({ example: 'user_789' }),
  owner_name: z.string().nullable().optional().openapi({ example: 'Aliolo' }),
  localized_data: z.string().openapi({ description: 'JSON string' }),
  created_at: z.string().openapi({ example: '2026-04-12T00:00:00Z' }),
  updated_at: z.string().openapi({ example: '2026-04-12T00:00:00Z' }),
}).openapi('Folder');

export const FoldersResponseSchema = z.array(FolderSchema);

export const CreateFolderSchema = z.object({
  id: z.string().openapi({ example: 'fold_123' }),
  pillar_id: z.number().openapi({ example: 1 }),
  localized_data: z.record(z.any()).openapi({ 
    example: { en: { name: 'My Folder' } } 
  }),
}).openapi('CreateFolder');
