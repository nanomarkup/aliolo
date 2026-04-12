-- Core Tables
CREATE TABLE IF NOT EXISTS pillars (
  id INTEGER PRIMARY KEY,
  sort_order INTEGER,
  light_color TEXT,
  dark_color TEXT,
  icon TEXT,
  localized_data TEXT -- JSON
);

CREATE TABLE IF NOT EXISTS profiles (
  id TEXT PRIMARY KEY, -- UUID
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
  sidebar_left INTEGER DEFAULT 0, -- Boolean
  sound_enabled INTEGER DEFAULT 1, -- Boolean
  auto_play_enabled INTEGER DEFAULT 0, -- Boolean
  show_on_leaderboard INTEGER DEFAULT 1, -- Boolean
  show_documentation INTEGER DEFAULT 1, -- Boolean
  learn_session_size INTEGER DEFAULT 10,
  test_session_size INTEGER DEFAULT 10,
  options_count INTEGER DEFAULT 6,
  avatar_url TEXT,
  password_hash TEXT,
  main_pillar_id INTEGER REFERENCES pillars(id),
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  is_premium INTEGER DEFAULT 0 -- Boolean
);

CREATE TABLE IF NOT EXISTS folders (
  id TEXT PRIMARY KEY,
  pillar_id INTEGER REFERENCES pillars(id) NOT NULL,
  owner_id TEXT REFERENCES profiles(id) NOT NULL,
  localized_data TEXT, -- JSON
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS collections (
  id TEXT PRIMARY KEY,
  pillar_id INTEGER REFERENCES pillars(id) NOT NULL,
  folder_id TEXT REFERENCES folders(id),
  owner_id TEXT REFERENCES profiles(id) NOT NULL,
  age_group TEXT DEFAULT 'advanced',
  is_public INTEGER DEFAULT 0, -- Boolean
  localized_data TEXT, -- JSON
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS subjects (
  id TEXT PRIMARY KEY,
  pillar_id INTEGER REFERENCES pillars(id) NOT NULL,
  folder_id TEXT REFERENCES folders(id),
  owner_id TEXT REFERENCES profiles(id) NOT NULL,
  age_group TEXT DEFAULT 'advanced',
  is_public INTEGER DEFAULT 0, -- Boolean
  localized_data TEXT, -- JSON
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS cards (
  id TEXT PRIMARY KEY,
  subject_id TEXT REFERENCES subjects(id) NOT NULL,
  owner_id TEXT REFERENCES profiles(id),
  level INTEGER DEFAULT 1,
  test_mode TEXT DEFAULT 'standard',
  is_public INTEGER DEFAULT 0, -- Boolean
  is_deleted INTEGER DEFAULT 0, -- Boolean
  localized_data TEXT, -- JSON
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Intermediary Tables
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

-- Progress & Social
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
  is_hidden INTEGER DEFAULT 0, -- Boolean
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, card_id)
);

CREATE TABLE IF NOT EXISTS user_friendships (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sender_id TEXT REFERENCES profiles(id),
  receiver_id TEXT REFERENCES profiles(id),
  status TEXT DEFAULT 'pending', -- 'pending', 'accepted', 'blocked'
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(sender_id, receiver_id)
);

-- Subscriptions & Internal
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

-- Feedback System
CREATE TABLE IF NOT EXISTS feedbacks (
  id TEXT PRIMARY KEY,
  user_id TEXT REFERENCES profiles(id) NOT NULL,
  type TEXT NOT NULL,
  content TEXT NOT NULL,
  status TEXT DEFAULT 'open',
  attachment_urls TEXT, -- JSON Array
  metadata TEXT, -- JSON
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS feedback_replies (
  id TEXT PRIMARY KEY,
  feedback_id TEXT REFERENCES feedbacks(id) ON DELETE CASCADE,
  user_id TEXT REFERENCES profiles(id) NOT NULL,
  content TEXT NOT NULL,
  attachment_urls TEXT, -- JSON Array
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Auth (Lucia specific)
CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  expires_at INTEGER NOT NULL
);

-- Languages
CREATE TABLE IF NOT EXISTS languages (
  id TEXT PRIMARY KEY, -- 'en', 'es', etc.
  name TEXT NOT NULL,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);
