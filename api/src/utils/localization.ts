import type { D1Database } from '@cloudflare/workers-types';

export type TranslationMap = Record<string, string>;

function normalizeTranslations(raw: unknown): TranslationMap | null {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return null;
  }

  const entries = Object.entries(raw as Record<string, unknown>);
  const normalized: TranslationMap = {};

  for (const [key, value] of entries) {
    if (typeof key !== 'string' || typeof value !== 'string') {
      return null;
    }
    normalized[key] = value;
  }

  return normalized;
}

export async function fetchTranslationRows(db: D1Database, lang: string): Promise<TranslationMap> {
  const { results } = await db.prepare(
    'SELECT key, value FROM ui_translations WHERE lang = ? ORDER BY key'
  ).bind(lang).all();

  const translations: TranslationMap = {};
  for (const row of results as any[]) {
    if (typeof row?.key === 'string' && typeof row?.value === 'string') {
      translations[row.key] = row.value;
    }
  }

  return translations;
}

export async function readTranslationBundle(db: D1Database, lang: string): Promise<TranslationMap | null> {
  const row = await db.prepare(
    'SELECT translations FROM ui_translation_bundles WHERE lang = ?'
  ).bind(lang).first<{ translations: string }>();

  if (!row?.translations) {
    return null;
  }

  try {
    return normalizeTranslations(JSON.parse(row.translations));
  } catch {
    return null;
  }
}

export async function writeTranslationBundle(
  db: D1Database,
  lang: string,
  translations: TranslationMap
): Promise<void> {
  await db.prepare(`
    INSERT INTO ui_translation_bundles (lang, translations, updated_at)
    VALUES (?, ?, CURRENT_TIMESTAMP)
    ON CONFLICT(lang) DO UPDATE SET
      translations = excluded.translations,
      updated_at = CURRENT_TIMESTAMP
  `).bind(lang, JSON.stringify(translations)).run();
}

export async function getTranslationsForLanguage(db: D1Database, lang: string): Promise<TranslationMap> {
  const lc = lang.toLowerCase();

  const bundle = await readTranslationBundle(db, lc);
  if (bundle) {
    return bundle;
  }

  const translations = await fetchTranslationRows(db, lc);
  if (Object.keys(translations).length > 0) {
    await writeTranslationBundle(db, lc, translations);
  }

  return translations;
}

export async function refreshTranslationBundle(db: D1Database, lang: string): Promise<TranslationMap> {
  const lc = lang.toLowerCase();
  const translations = await fetchTranslationRows(db, lc);
  await writeTranslationBundle(db, lc, translations);
  return translations;
}

export async function refreshAllTranslationBundles(db: D1Database): Promise<void> {
  const { results } = await db.prepare(
    'SELECT DISTINCT lang FROM ui_translations ORDER BY lang'
  ).all<{ lang: string }>();

  for (const row of results) {
    if (typeof row.lang === 'string' && row.lang.trim().length > 0) {
      await refreshTranslationBundle(db, row.lang);
    }
  }
}
