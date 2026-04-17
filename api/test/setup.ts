import { beforeAll } from 'vitest';
import { env } from 'cloudflare:test';

const SCHEMA = `
CREATE TABLE IF NOT EXISTS pillars (
  id INTEGER PRIMARY KEY,
  sort_order INTEGER,
  light_color TEXT,
  dark_color TEXT,
  icon TEXT,
  name TEXT,
  names TEXT,
  description TEXT,
  descriptions TEXT
);

CREATE TABLE IF NOT EXISTS profiles (
  id TEXT PRIMARY KEY,
  username TEXT,
  email TEXT UNIQUE,
  total_xp INTEGER DEFAULT 0,
  current_streak INTEGER DEFAULT 0,
  max_streak INTEGER DEFAULT 0,
  theme_mode TEXT DEFAULT 'system',
  ui_language TEXT DEFAULT 'en',
  default_language TEXT DEFAULT 'en',
  daily_goal_count INTEGER DEFAULT 20,
  next_daily_goal INTEGER DEFAULT 20,
  daily_completions REAL DEFAULT 0,
  last_active_date TEXT,
  sidebar_left INTEGER DEFAULT 0,
  sound_enabled INTEGER DEFAULT 1,
  auto_play_enabled INTEGER DEFAULT 0,
  show_on_leaderboard INTEGER DEFAULT 1,
  show_documentation INTEGER DEFAULT 1,
  learn_session_size INTEGER DEFAULT 10,
  test_session_size INTEGER DEFAULT 10,
  options_count INTEGER DEFAULT 6,
  avatar_url TEXT,
  password_hash TEXT,
  main_pillar_id INTEGER REFERENCES pillars(id),
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  is_premium INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS folders (
  id TEXT PRIMARY KEY,
  pillar_id INTEGER REFERENCES pillars(id) NOT NULL,
  owner_id TEXT REFERENCES profiles(id) NOT NULL,
  name TEXT,
  names TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS collections (
  id TEXT PRIMARY KEY,
  pillar_id INTEGER REFERENCES pillars(id) NOT NULL,
  folder_id TEXT REFERENCES folders(id),
  owner_id TEXT REFERENCES profiles(id) NOT NULL,
  age_group TEXT DEFAULT 'advanced',
  is_public INTEGER DEFAULT 0,
  name TEXT,
  names TEXT,
  description TEXT,
  descriptions TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS subjects (
  id TEXT PRIMARY KEY,
  pillar_id INTEGER REFERENCES pillars(id) NOT NULL,
  folder_id TEXT REFERENCES folders(id),
  owner_id TEXT REFERENCES profiles(id) NOT NULL,
  age_group TEXT DEFAULT 'advanced',
  is_public INTEGER DEFAULT 0,
  name TEXT,
  names TEXT,
  description TEXT,
  descriptions TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS cards (
  id TEXT PRIMARY KEY,
  subject_id TEXT REFERENCES subjects(id) NOT NULL,
  owner_id TEXT REFERENCES profiles(id),
  level INTEGER DEFAULT 1,
  renderer TEXT DEFAULT 'generic',
  is_public INTEGER DEFAULT 1,
  answer TEXT,
  answers TEXT,
  prompt TEXT,
  prompts TEXT,
  display_text TEXT DEFAULT '',
  display_texts TEXT DEFAULT '{}',
  images_base TEXT,
  images_local TEXT,
  audio TEXT,
  audios TEXT,
  video TEXT,
  videos TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS collection_items (
  id TEXT PRIMARY KEY,
  collection_id TEXT REFERENCES collections(id) ON DELETE CASCADE,
  subject_id TEXT REFERENCES subjects(id) ON DELETE CASCADE,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS user_subjects (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT REFERENCES profiles(id) ON DELETE CASCADE,
  subject_id TEXT REFERENCES subjects(id),
  collection_id TEXT REFERENCES collections(id),
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, subject_id, collection_id)
);

CREATE TABLE IF NOT EXISTS progress (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT REFERENCES profiles(id) ON DELETE CASCADE,
  card_id TEXT REFERENCES cards(id) ON DELETE CASCADE,
  subject_id TEXT REFERENCES subjects(id),
  correct_count INTEGER DEFAULT 0,
  repetition_count INTEGER DEFAULT 0,
  interval INTEGER DEFAULT 0,
  ease_factor REAL DEFAULT 2.5,
  next_review TEXT,
  is_hidden INTEGER DEFAULT 0,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, card_id)
);

CREATE TABLE IF NOT EXISTS user_friendships (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sender_id TEXT REFERENCES profiles(id),
  receiver_id TEXT REFERENCES profiles(id),
  status TEXT DEFAULT 'pending',
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(sender_id, receiver_id)
);

CREATE TABLE IF NOT EXISTS user_subscriptions (
  id TEXT PRIMARY KEY,
  user_id TEXT REFERENCES profiles(id) UNIQUE NOT NULL,
  status TEXT NOT NULL DEFAULT 'inactive',
  provider TEXT NOT NULL,
  expiry_date TEXT,
  purchase_token TEXT,
  order_id TEXT,
  product_id TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ui_translations (
  key TEXT NOT NULL,
  lang TEXT NOT NULL,
  value TEXT NOT NULL,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (key, lang)
);

CREATE TABLE IF NOT EXISTS onboarding_analytics (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL,
  age_range TEXT,
  pillar_id INTEGER,
  last_slide_index INTEGER,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(session_id)
);

CREATE TABLE IF NOT EXISTS feedbacks (
  id TEXT PRIMARY KEY,
  user_id TEXT REFERENCES profiles(id) NOT NULL,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  status TEXT DEFAULT 'open',
  attachment_urls TEXT,
  metadata TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS feedback_replies (
  id TEXT PRIMARY KEY,
  feedback_id TEXT REFERENCES feedbacks(id) ON DELETE CASCADE,
  user_id TEXT REFERENCES profiles(id) NOT NULL,
  content TEXT NOT NULL,
  attachment_urls TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  expires_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS languages (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS email_verification_codes (
  email TEXT PRIMARY KEY,
  code TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  is_verified INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS invitations (
  token TEXT PRIMARY KEY,
  email TEXT NOT NULL,
  inviter_id TEXT NOT NULL,
  expires_at INTEGER NOT NULL
);
`;

beforeAll(async () => {
  // Split the schema into individual statements
  const statements = SCHEMA.split(';').filter(s => s.trim().length > 0);
  for (const statement of statements) {
    try {
      await env.DB.prepare(statement).run();
    } catch (e) {
      console.error('Failed to execute statement:', statement, e);
    }
  }

  // Add default pillar
  await env.DB.prepare("INSERT OR IGNORE INTO pillars (id, sort_order) VALUES (6, 6)").run();
});
