import { z } from '@hono/zod-openapi';

export const FolderSchema = z.object({
  id: z.string().openapi({ example: 'fold_123' }),
  pillar_id: z.number().openapi({ example: 1 }),
  owner_id: z.string().openapi({ example: 'user_789' }),
  owner_name: z.string().nullable().optional().openapi({ example: 'Aliolo' }),
  name: z.string().openapi({ example: 'My Folder' }),
  names: z.string().openapi({ 
    description: 'JSON string containing localized names',
    example: '{"es": "Mi Carpeta"}' 
  }),
  created_at: z.string().openapi({ example: '2026-04-12T00:00:00Z' }),
  updated_at: z.string().openapi({ example: '2026-04-12T00:00:00Z' }),
}).openapi('Folder');

export const FoldersResponseSchema = z.array(FolderSchema);

export const CreateFolderSchema = z.object({
  id: z.string().openapi({ example: 'fold_123' }),
  pillar_id: z.number().openapi({ example: 1 }),
  name: z.string().min(1, 'Name is required').openapi({ example: 'My Folder' }),
  names: z.record(z.string()).openapi({ example: { es: 'Mi Carpeta' } }),
}).openapi('CreateFolder');
