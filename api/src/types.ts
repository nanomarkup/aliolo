import type { User, Session } from "lucia";

export type Bindings = {
  DB: D1Database;
  MEDIA: R2Bucket;
  ASSETS: Fetcher;
  ENVIRONMENT?: string;
  SUBSCRIPTION_VERIFICATION_MODE?: string;
  GOOGLE_PLAY_VERIFICATION_MODE?: string;
  GOOGLE_PLAY_PACKAGE_NAME?: string;
  GOOGLE_PLAY_SERVICE_ACCOUNT_JSON?: string;
  GOOGLE_PLAY_VERIFIER_URL?: string;
  GOOGLE_PLAY_VERIFIER_SHARED_SECRET?: string;
  PADDLE_API_KEY?: string;
  PADDLE_CLIENT_TOKEN?: string;
  PADDLE_PRICE_WEEKLY?: string;
  PADDLE_PRICE_MONTHLY?: string;
  PADDLE_PRICE_YEARLY?: string;
  PADDLE_WEBHOOK_SECRET?: string;
  GMAIL_APP_PASSWORD?: string;
  SMTP_USER?: string;
  EMAIL_SENDER?: string;
};

export type AppEnv = { Bindings: Bindings; Variables: { user: User | null; session: Session | null } };
