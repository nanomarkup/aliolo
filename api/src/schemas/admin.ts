import { z } from '@hono/zod-openapi';
import { UserProfileSchema } from './auth';

export const AdminSubscriptionSchema = z.object({
  id: z.string().nullable().openapi({ example: 'sub_123' }),
  user_id: z.string().nullable().openapi({ example: 'abc123xyz' }),
  status: z.string().nullable().openapi({ example: 'active' }),
  provider: z.string().nullable().openapi({ example: 'google_play' }),
  effective_source: z.string().nullable().openapi({ example: 'provider' }),
  expiry_date: z.string().nullable().openapi({ example: '2026-04-12T00:00:00Z' }),
  purchase_token: z.string().nullable().openapi({ example: 'token_123' }),
  order_id: z.string().nullable().openapi({ example: 'order_123' }),
  product_id: z.string().nullable().openapi({ example: 'premium_yearly' }),
  active_provider_subscription_id: z.string().nullable().openapi({ example: 'prov_123' }),
  active_manual_grant_id: z.string().nullable().openapi({ example: 'grant_123' }),
  created_at: z.string().nullable().openapi({ example: '2026-04-12T00:00:00Z' }),
  updated_at: z.string().nullable().openapi({ example: '2026-04-12T00:00:00Z' }),
}).openapi('AdminSubscription');

export const AdminUserSchema = UserProfileSchema.extend({
  subscription: AdminSubscriptionSchema.nullable(),
}).openapi('AdminUser');

export const AdminUsersFilterSchema = z.enum(['all', 'free', 'premium', 'fake']);

export const AdminUsersResponseSchema = z.object({
  users: z.array(AdminUserSchema),
  page: z.number().int().min(0).openapi({ example: 0 }),
  pageSize: z.number().int().min(1).openapi({ example: 25 }),
  totalCount: z.number().int().min(0).openapi({ example: 120 }),
  totalPages: z.number().int().min(0).openapi({ example: 5 }),
  overallCount: z.number().int().min(0).openapi({ example: 240 }),
}).openapi('AdminUsersResponse');

export const AdminSubjectUsageSchema = z.object({
  subject_id: z.string().openapi({ example: 'subject_123' }),
  subject_name: z.string().openapi({ example: 'World Bridges' }),
  pillar_name: z.string().nullable().openapi({ example: 'World' }),
  folder_name: z.string().nullable().openapi({ example: 'Architecture' }),
  total_started: z.number().int().openapi({ example: 120 }),
  total_completed: z.number().int().openapi({ example: 96 }),
  learn_started: z.number().int().openapi({ example: 80 }),
  learn_completed: z.number().int().openapi({ example: 72 }),
  test_started: z.number().int().openapi({ example: 40 }),
  test_completed: z.number().int().openapi({ example: 24 }),
  completion_rate: z.number().openapi({ example: 0.8 }),
  updated_at: z.string().nullable().openapi({ example: '2026-04-12T00:00:00Z' }),
}).openapi('AdminSubjectUsage');

export const AdminSubjectUsageResponseSchema = z.array(AdminSubjectUsageSchema);

export const AdminOnboardingAnalyticsSummarySchema = z.object({
  total_sessions: z.number().int().min(0).openapi({ example: 42 }),
  linked_email_sessions: z.number().int().min(0).openapi({ example: 18 }),
  age_selected_sessions: z.number().int().min(0).openapi({ example: 35 }),
  pillar_selected_sessions: z.number().int().min(0).openapi({ example: 31 }),
  final_slide_sessions: z.number().int().min(0).openapi({ example: 12 }),
  unique_emails: z.number().int().min(0).openapi({ example: 16 }),
  average_last_slide_index: z.number().nullable().openapi({ example: 3.4 }),
  completion_rate: z.number().openapi({ example: 0.29 }),
  final_slide_index: z.number().int().min(0).openapi({ example: 6 }),
  latest_updated_at: z.string().nullable().openapi({ example: '2026-04-12T00:00:00Z' }),
}).openapi('AdminOnboardingAnalyticsSummary');

export const AdminOnboardingAgeBreakdownSchema = z.object({
  age_range: z.string().openapi({ example: 'age_19_25' }),
  sessions: z.number().int().min(0).openapi({ example: 14 }),
}).openapi('AdminOnboardingAgeBreakdown');

export const AdminOnboardingPillarBreakdownSchema = z.object({
  pillar_id: z.number().nullable().openapi({ example: 6 }),
  pillar_name: z.string().openapi({ example: 'Academic & Professional' }),
  sessions: z.number().int().min(0).openapi({ example: 11 }),
}).openapi('AdminOnboardingPillarBreakdown');

export const AdminOnboardingSlideBreakdownSchema = z.object({
  last_slide_index: z.number().nullable().openapi({ example: 6 }),
  sessions: z.number().int().min(0).openapi({ example: 7 }),
}).openapi('AdminOnboardingSlideBreakdown');

export const AdminOnboardingSessionSchema = z.object({
  session_id: z.string().openapi({ example: 'session_123' }),
  user_email: z.string().nullable().openapi({ example: 'user@example.com' }),
  age_range: z.string().nullable().openapi({ example: 'age_19_25' }),
  pillar_id: z.number().nullable().openapi({ example: 6 }),
  pillar_name: z.string().nullable().openapi({ example: 'Academic & Professional' }),
  last_slide_index: z.number().nullable().openapi({ example: 3 }),
  created_at: z.string().nullable().openapi({ example: '2026-04-12T00:00:00Z' }),
  updated_at: z.string().nullable().openapi({ example: '2026-04-12T00:00:00Z' }),
}).openapi('AdminOnboardingSession');

export const AdminOnboardingAnalyticsResponseSchema = z.object({
  summary: AdminOnboardingAnalyticsSummarySchema,
  age_breakdown: z.array(AdminOnboardingAgeBreakdownSchema),
  pillar_breakdown: z.array(AdminOnboardingPillarBreakdownSchema),
  slide_breakdown: z.array(AdminOnboardingSlideBreakdownSchema),
  recent_sessions: z.array(AdminOnboardingSessionSchema),
}).openapi('AdminOnboardingAnalyticsResponse');
