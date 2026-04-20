import { z } from '@hono/zod-openapi';

export const SubjectSchema = z.object({
  id: z.string().openapi({ example: 'subj_123' }),
  pillar_id: z.number().openapi({ example: 1 }),
  folder_id: z.string().nullable().openapi({ example: 'fold_456' }),
  owner_id: z.string().openapi({ example: 'user_789' }),
  owner_name: z.string().nullable().optional().openapi({ example: 'Aliolo' }),
  is_public: z.number().openapi({ example: 1 }),
  age_group: z.string().openapi({ example: 'primary' }),
  name: z.string().openapi({ example: 'Sports' }),
  names: z.string().openapi({ 
    description: 'JSON string containing localized names',
    example: '{"es": "Deportes"}' 
  }),
  description: z.string().openapi({ example: 'Master the names and rules of popular athletic games.' }),
  descriptions: z.string().openapi({ 
    description: 'JSON string containing localized descriptions',
    example: '{"es": "Domina los nombres y reglas de los juegos atléticos populares."}' 
  }),
  created_at: z.string().openapi({ example: '2026-04-12T00:00:00Z' }),
  updated_at: z.string().openapi({ example: '2026-04-12T00:00:00Z' }),
  card_count: z.number().openapi({ example: 50 }),
  is_on_dashboard: z.boolean().optional().openapi({ example: true }),
}).openapi('Subject');

export const SubjectsResponseSchema = z.array(SubjectSchema);

export const CreateSubjectSchema = z.object({
  id: z.string().openapi({ example: 'subj_123' }),
  pillar_id: z.number().openapi({ example: 1 }),
  folder_id: z.string().nullable().optional().openapi({ example: 'fold_456' }),
  is_public: z.boolean().optional().openapi({ example: true }),
  age_group: z.string().openapi({ example: 'primary' }),
  name: z.string().min(1, 'Name is required').openapi({ example: 'New Subject' }),
  names: z.record(z.string()).openapi({ example: { es: 'Nueva Materia' } }),
  description: z.string().openapi({ example: 'Desc' }),
  descriptions: z.record(z.string()).openapi({ example: { es: 'Desc' } }),
}).openapi('CreateSubject');

export const ToggleDashboardSchema = z.object({
  subject_id: z.string().optional().openapi({ example: 'subj_123' }),
  collection_id: z.string().optional().openapi({ example: 'coll_456' }),
  show: z.boolean().openapi({ example: true }),
}).openapi('ToggleDashboard');
