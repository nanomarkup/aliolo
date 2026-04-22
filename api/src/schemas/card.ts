import { z } from '@hono/zod-openapi';

export const CardSchema = z.object({
  id: z.string().openapi({ example: 'card_123' }),
  subject_id: z.string().openapi({ example: 'subj_456' }),
  owner_id: z.string().nullable().openapi({ example: 'user_789' }),
  level: z.number().openapi({ example: 1 }),
  renderer: z.string().openapi({ example: 'generic' }),
  is_public: z.number().openapi({ example: 1 }),
  answer: z.string().openapi({ example: 'Helix Bridge' }),
  answers: z.string().openapi({ description: 'JSON map of localized answers', example: '{"es": "Puente"}' }),
  prompt: z.string().openapi({ example: 'What is this?' }),
  prompts: z.string().openapi({ description: 'JSON map of localized prompts' }),
  display_text: z.string().openapi({ example: '1 + 3' }),
  display_texts: z.string().openapi({ description: 'JSON map of localized display text' }),
  images_base: z.string().openapi({ description: 'JSON array of base image URLs' }),
  images_local: z.string().openapi({ description: 'JSON map of localized image URL arrays' }),
  audio: z.string().openapi({ example: 'url_to_audio' }),
  audios: z.string().openapi({ description: 'JSON map of localized audio URLs' }),
  video: z.string().openapi({ example: 'url_to_video' }),
  videos: z.string().openapi({ description: 'JSON map of localized video URLs' }),
  created_at: z.string().openapi({ example: '2026-04-12T00:00:00Z' }),
  updated_at: z.string().openapi({ example: '2026-04-12T00:00:00Z' }),
}).openapi('Card');

export const CardsResponseSchema = z.array(CardSchema);

export const CardCountSchema = z.object({
  count: z.number().openapi({ example: 42 }),
}).openapi('CardCount');

export const CreateCardSchema = z.object({
  id: z.string().openapi({ example: 'card_123' }),
  subject_id: z.string().openapi({ example: 'subj_456' }),
  level: z.number().optional().openapi({ example: 1 }),
  renderer: z.string().optional().openapi({ example: 'generic' }),
  is_public: z.boolean().optional().openapi({ example: true }),
  answer: z.string().min(1, 'Answer is required').openapi({ example: 'A' }),
  answers: z.record(z.string()).openapi({ example: { es: 'A' } }),
  prompt: z.string().openapi({ example: 'Choose A' }),
  prompts: z.record(z.string()).openapi({ example: { es: 'Elige A' } }),
  display_text: z.string().optional().openapi({ example: '1 + 3' }),
  display_texts: z.record(z.string()).optional().openapi({ example: { es: '1 + 3' } }),
  images_base: z.array(z.string()).openapi({ example: ['url1', 'url2'] }),
  images_local: z.record(z.array(z.string())).openapi({ example: { es: ['url_es'] } }),
  audio: z.string().openapi({ example: 'url' }),
  audios: z.record(z.string()).openapi({ example: { es: 'url_es' } }),
  video: z.string().openapi({ example: 'url' }),
  videos: z.record(z.string()).openapi({ example: { es: 'url_es' } }),
}).openapi('CreateCard').refine(data => {
  return (data.display_text && data.display_text.trim().length > 0) || 
         data.images_base.length > 0 || 
         data.audio.trim().length > 0 || 
         data.video.trim().length > 0;
}, {
  message: "At least one visual content (text, image, audio, or video) must be provided.",
  path: ["display_text"]
});
