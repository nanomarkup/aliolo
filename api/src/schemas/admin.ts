import { z } from '@hono/zod-openapi';
import { UserProfileSchema } from './auth';

export const AdminSubscriptionSchema = z.object({
  id: z.string().nullable().openapi({ example: 'sub_123' }),
  user_id: z.string().nullable().openapi({ example: 'abc123xyz' }),
  status: z.string().nullable().openapi({ example: 'active' }),
  provider: z.string().nullable().openapi({ example: 'aliolo' }),
  expiry_date: z.string().nullable().openapi({ example: '2026-04-12T00:00:00Z' }),
  purchase_token: z.string().nullable().openapi({ example: 'token_123' }),
  order_id: z.string().nullable().openapi({ example: 'order_123' }),
  product_id: z.string().nullable().openapi({ example: 'premium_yearly' }),
  created_at: z.string().nullable().openapi({ example: '2026-04-12T00:00:00Z' }),
  updated_at: z.string().nullable().openapi({ example: '2026-04-12T00:00:00Z' }),
}).openapi('AdminSubscription');

export const AdminUserSchema = UserProfileSchema.extend({
  subscription: AdminSubscriptionSchema.nullable(),
}).openapi('AdminUser');

export const AdminUsersResponseSchema = z.array(AdminUserSchema);
