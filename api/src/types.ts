import type { User, Session } from "lucia";

export type Bindings = {
  DB: D1Database;
  MEDIA: R2Bucket;
  AVATARS: R2Bucket;
  ASSETS: Fetcher;
  ENVIRONMENT?: string;
};

export type AppEnv = { Bindings: Bindings; Variables: { user: User | null; session: Session | null } };