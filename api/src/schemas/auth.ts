import { z } from '@hono/zod-openapi';

export const SignupRequestSchema = z.object({
  email: z.string().email().openapi({ example: 'user@example.com' }),
  password: z.string().min(6).openapi({ example: 'securepassword123' }),
  username: z.string().optional().openapi({ example: 'johndoe' }),
}).openapi('SignupRequest');

export const SignupInviteRequestSchema = z.object({
  email: z.string().email().openapi({ example: 'user@example.com' }),
  password: z.string().min(6).openapi({ example: 'securepassword123' }),
  username: z.string().optional().openapi({ example: 'johndoe' }),
  invite_token: z.string().openapi({ example: 'abc123token' }),
}).openapi('SignupInviteRequest');

export const LoginRequestSchema = z.object({
  email: z.string().email().openapi({ example: 'user@example.com' }),
  password: z.string().openapi({ example: 'securepassword123' }),
}).openapi('LoginRequest');

export const UserSchema = z.object({
  id: z.string().openapi({ example: 'abc123xyz' }),
  email: z.string().email().openapi({ example: 'user@example.com' }),
  username: z.string().nullable().optional().openapi({ example: 'johndoe' }),
}).openapi('User');

export const AuthResponseSchema = z.object({
  user: UserSchema,
  session_id: z.string().openapi({ example: 'sess_123456789' }),
}).openapi('AuthResponse');

export const UserProfileSchema = z.object({
  id: z.string().openapi({ example: 'abc123xyz' }),
  username: z.string().nullable().openapi({ example: 'johndoe' }),
  email: z.string().email().openapi({ example: 'user@example.com' }),
  total_xp: z.number().openapi({ example: 100 }),
  current_streak: z.number().openapi({ example: 5 }),
  max_streak: z.number().openapi({ example: 10 }),
  theme_mode: z.string().openapi({ example: 'system' }),
  ui_language: z.string().openapi({ example: 'en' }),
  default_language: z.string().openapi({ example: 'en' }),
  daily_goal_count: z.number().openapi({ example: 20 }),
  next_daily_goal: z.number().openapi({ example: 20 }),
  daily_completions: z.number().openapi({ example: 5 }),
  last_active_date: z.string().nullable().openapi({ example: '2026-04-12T00:00:00Z' }),
  sidebar_left: z.number().openapi({ example: 0 }),
  sound_enabled: z.number().openapi({ example: 1 }),
  auto_play_enabled: z.number().openapi({ example: 0 }),
  show_on_leaderboard: z.number().openapi({ example: 1 }),
  show_documentation: z.number().openapi({ example: 1 }),
  learn_session_size: z.number().openapi({ example: 10 }),
  test_session_size: z.number().openapi({ example: 10 }),
  test_mode: z.string().openapi({ example: 'question_to_answer' }),
  learn_autoplay_delay_seconds: z.number().openapi({ example: 3 }),
  options_count: z.number().openapi({ example: 6 }),
  avatar_url: z.string().nullable().openapi({ example: 'https://example.com/avatar.png' }),
  main_pillar_id: z.number().nullable().openapi({ example: 1 }),
  last_age_group: z.string().optional().openapi({ example: 'all' }),
  last_source_filter: z.string().optional().openapi({ example: 'all' }),
  created_at: z.string().openapi({ example: '2026-04-12T00:00:00Z' }),
  updated_at: z.string().openapi({ example: '2026-04-12T00:00:00Z' }),
  is_premium: z.number().openapi({ example: 0 }),
  card_limit: z.number().openapi({ example: 200 }),
}).openapi('UserProfile');

export const MeResponseSchema = z.object({
  user: UserProfileSchema.nullable(),
}).openapi('MeResponse');

export const UpdateProfileSchema = z.object({
  username: z.string().optional().openapi({ example: 'newusername' }),
  theme_mode: z.string().optional().openapi({ example: 'dark' }),
  ui_language: z.string().optional().openapi({ example: 'es' }),
  default_language: z.string().optional().openapi({ example: 'es' }),
  daily_goal_count: z.number().optional().openapi({ example: 30 }),
  next_daily_goal: z.number().optional().openapi({ example: 30 }),
  daily_completions: z.number().optional().openapi({ example: 10 }),
  last_active_date: z.string().optional().openapi({ example: '2026-04-12T00:00:00Z' }),
  sidebar_left: z.union([z.boolean(), z.number()]).optional().openapi({ example: 1 }),
  sound_enabled: z.union([z.boolean(), z.number()]).optional().openapi({ example: 0 }),
  auto_play_enabled: z.union([z.boolean(), z.number()]).optional().openapi({ example: 1 }),
  show_on_leaderboard: z.union([z.boolean(), z.number()]).optional().openapi({ example: 0 }),
  show_documentation: z.union([z.boolean(), z.number()]).optional().openapi({ example: 0 }),
  learn_session_size: z.number().optional().openapi({ example: 20 }),
  test_session_size: z.number().optional().openapi({ example: 20 }),
  test_mode: z.string().optional().openapi({ example: 'random' }),
  learn_autoplay_delay_seconds: z.number().optional().openapi({ example: 4 }),
  options_count: z.number().optional().openapi({ example: 4 }),
  avatar_url: z.string().optional().openapi({ example: 'https://example.com/new_avatar.png' }),
  main_pillar_id: z.number().optional().openapi({ example: 2 }),
  last_age_group: z.string().optional().openapi({ example: 'all' }),
  last_source_filter: z.string().optional().openapi({ example: 'all' }),
  is_premium: z.union([z.boolean(), z.number()]).optional().openapi({ example: 1 }),
  card_limit: z.number().optional().openapi({ example: 200 }),
}).openapi('UpdateProfile');

export const SuccessResponseSchema = z.object({
  success: z.boolean().optional().openapi({ example: true }),
  message: z.string().optional().openapi({ example: 'Logged out' }),
}).openapi('SuccessResponse');

export const ErrorResponseSchema = z.object({
  error: z.string().openapi({ example: 'Error message' }),
}).openapi('ErrorResponse');

export const RequestOtpSchema = z.object({
  email: z.string().email().openapi({ example: 'user@example.com' }),
}).openapi('RequestOtp');

export const VerifyOtpSchema = z.object({
  email: z.string().email().openapi({ example: 'user@example.com' }),
  code: z.string().length(6).openapi({ example: '123456' }),
}).openapi('VerifyOtp');

export const ResetPasswordSchema = z.object({
  email: z.string().email().openapi({ example: 'user@example.com' }),
  code: z.string().length(6).openapi({ example: '123456' }),
  password: z.string().min(6).openapi({ example: 'newpassword123' }),
}).openapi('ResetPassword');

export const DeleteAccountSchema = z.object({
  password: z.string().openapi({ example: 'securepassword123' }),
}).openapi('DeleteAccount');

export const UpdatePasswordSchema = z.object({
  new_password: z.string().min(6).openapi({ example: 'newsecurepassword123' }),
}).openapi('UpdatePassword');

export const RequestEmailChangeSchema = z.object({
  new_email: z.string().email().openapi({ example: 'newuser@example.com' }),
  password: z.string().openapi({ example: 'securepassword123' }),
}).openapi('RequestEmailChange');

export const VerifyEmailChangeSchema = z.object({
  new_email: z.string().email().openapi({ example: 'newuser@example.com' }),
  code: z.string().length(6).openapi({ example: '123456' }),
}).openapi('VerifyEmailChange');

export const InviteUserSchema = z.object({
  email: z.string().email().openapi({ example: 'friend@example.com' }),
}).openapi('InviteUser');
