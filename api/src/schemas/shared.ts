import { z } from '@hono/zod-openapi';

export const SuccessResponseSchema = z.object({
  success: z.boolean().openapi({ example: true }),
}).openapi('SuccessResponse');

export const MessageResponseSchema = z.object({
  message: z.string().openapi({ example: 'Operation successful' }),
}).openapi('MessageResponse');

export const ErrorResponseSchema = z.object({
  error: z.string().openapi({ example: 'An error occurred' }),
}).openapi('ErrorResponse');
