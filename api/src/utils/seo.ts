import { D1Database } from '@cloudflare/workers-types';

const BASE_URL = 'https://aliolo.com';
const DEFAULT_OG_IMAGE = `${BASE_URL}/aliolo-social-preview.png`;

type SeoEntity =
  | {
      kind: 'subject';
      id: string;
      name: string;
      description: string | null;
      cards: Array<{ prompt: string | null; answer: string | null }>;
      canonicalPath: string;
    }
  | {
      kind: 'collection';
      id: string;
      name: string;
      description: string | null;
      subjects: Array<{ id: string; name: string | null; description: string | null }>;
      canonicalPath: string;
    };

export async function generateSeoHtml(
  db: D1Database,
  pathname: string,
  originalHtml: string,
): Promise<string | null> {
  try {
    const entity = await resolveSeoEntity(db, pathname);
    if (!entity) return null;

    const title =
      entity.kind === 'subject'
        ? `${entity.name} Flashcards | Aliolo`
        : `${entity.name} Collection | Aliolo`;

    const description = buildDescription(entity);
    const canonicalUrl = `${BASE_URL}${entity.canonicalPath}`;
    const routePreview = buildPreviewHtml(entity, description);
    const jsonLd = JSON.stringify(buildStructuredData(entity, description, canonicalUrl));

    let html = originalHtml;
    html = replaceOrInsert(
      html,
      /<title>[\s\S]*?<\/title>/i,
      `<title>${escapeHtml(title)}</title>`,
      '</head>',
    );
    html = replaceOrInsert(
      html,
      /<meta\s+name="description"\s+content="[^"]*"\s*\/?>/i,
      `<meta name="description" content="${escapeHtml(description)}">`,
      '</head>',
    );
    html = replaceOrInsert(
      html,
      /<meta\s+name="robots"\s+content="[^"]*"\s*\/?>/i,
      '<meta name="robots" content="index,follow,max-image-preview:large,max-snippet:-1,max-video-preview:-1">',
      '</head>',
    );
    html = replaceOrInsert(
      html,
      /<link\s+rel="canonical"\s+href="[^"]*"\s*\/?>/i,
      `<link rel="canonical" href="${canonicalUrl}">`,
      '</head>',
    );

    const headExtras = [
      '<meta property="og:type" content="website">',
      `<meta property="og:title" content="${escapeHtml(title)}">`,
      `<meta property="og:description" content="${escapeHtml(description)}">`,
      `<meta property="og:url" content="${canonicalUrl}">`,
      `<meta property="og:image" content="${DEFAULT_OG_IMAGE}">`,
      '<meta property="og:image:width" content="1200">',
      '<meta property="og:image:height" content="630">',
      '<meta property="og:image:alt" content="Aliolo visual learning cards and spaced repetition preview">',
      '<meta name="twitter:card" content="summary_large_image">',
      `<meta name="twitter:title" content="${escapeHtml(title)}">`,
      `<meta name="twitter:description" content="${escapeHtml(description)}">`,
      `<meta name="twitter:image" content="${DEFAULT_OG_IMAGE}">`,
      `<script type="application/ld+json">${jsonLd}</script>`,
    ].join('');

    html = html.replace('</head>', `${headExtras}</head>`);
    html = html.replace(
      '<body>',
      `<body>${routePreview}<script>
        (() => {
          const cleanup = () => {
            const shell = document.getElementById('aliolo-seo-shell');
            if (shell) shell.remove();
          };
          window.addEventListener('flutter-first-frame', cleanup, { once: true });
          const observer = new MutationObserver(() => {
            if (document.querySelector('flutter-view, flt-glass-pane')) {
              observer.disconnect();
              cleanup();
            }
          });
          observer.observe(document.documentElement, { childList: true, subtree: true });
          setTimeout(() => {
            observer.disconnect();
            cleanup();
          }, 15000);
        })();
      </script>`,
    );

    return html;
  } catch (e) {
    console.error('SEO Generation error:', e);
    return null;
  }
}

async function resolveSeoEntity(
  db: D1Database,
  pathname: string,
): Promise<SeoEntity | null> {
  if (pathname.startsWith('/subject/')) {
    const subjectId = pathname.split('/')[2];
    return fetchSubjectSeoEntity(db, subjectId, `/subject/${subjectId}`);
  }

  if (pathname.startsWith('/collection/')) {
    const collectionId = pathname.split('/')[2];
    return fetchCollectionSeoEntity(db, collectionId, `/collection/${collectionId}`);
  }

  if (pathname.startsWith('/goals/')) {
    const slug = pathname.split('/')[2];
    if (!slug) return null;

    const subject = await db
      .prepare(
        `SELECT id
         FROM subjects
         WHERE (is_public = 1 OR is_public = true)
           AND REPLACE(LOWER(name), ' ', '-') = ?
         LIMIT 1`,
      )
      .bind(slug)
      .first<{ id: string }>();

    if (!subject) return null;

    return fetchSubjectSeoEntity(db, subject.id, `/subject/${subject.id}`);
  }

  return null;
}

async function fetchSubjectSeoEntity(
  db: D1Database,
  subjectId: string,
  canonicalPath: string,
): Promise<SeoEntity | null> {
  const subject = await db
    .prepare(
      `SELECT id, name, description
       FROM subjects
       WHERE id = ?
         AND (is_public = 1 OR is_public = true)
       LIMIT 1`,
    )
    .bind(subjectId)
    .first<{ id: string; name: string; description: string | null }>();

  if (!subject) return null;

  const cardsResult = await db
    .prepare(
      `SELECT prompt, answer
       FROM cards
       WHERE subject_id = ?
         AND (is_public = 1 OR is_public = true)
       ORDER BY updated_at DESC
       LIMIT 10`,
    )
    .bind(subjectId)
    .all<{ prompt: string | null; answer: string | null }>();

  return {
    kind: 'subject',
    id: subject.id,
    name: subject.name,
    description: subject.description,
    cards: cardsResult.results,
    canonicalPath,
  };
}

async function fetchCollectionSeoEntity(
  db: D1Database,
  collectionId: string,
  canonicalPath: string,
): Promise<SeoEntity | null> {
  const collection = await db
    .prepare(
      `SELECT id, name, description
       FROM collections
       WHERE id = ?
         AND (is_public = 1 OR is_public = true)
       LIMIT 1`,
    )
    .bind(collectionId)
    .first<{ id: string; name: string; description: string | null }>();

  if (!collection) return null;

  const subjectsResult = await db
    .prepare(
      `SELECT s.id, s.name, s.description
       FROM collection_items ci
       JOIN subjects s ON s.id = ci.subject_id
       WHERE ci.collection_id = ?
         AND (s.is_public = 1 OR s.is_public = true)
       ORDER BY s.updated_at DESC
       LIMIT 10`,
    )
    .bind(collectionId)
    .all<{ id: string; name: string | null; description: string | null }>();

  return {
    kind: 'collection',
    id: collection.id,
    name: collection.name,
    description: collection.description,
    subjects: subjectsResult.results,
    canonicalPath,
  };
}

function buildDescription(entity: SeoEntity): string {
  if (entity.description && entity.description.trim().length > 0) {
    return entity.description.trim();
  }

  if (entity.kind === 'subject') {
    return `Study ${entity.name} with visual flashcards, spaced repetition, and focused review in Aliolo.`;
  }

  return `Explore the ${entity.name} study collection in Aliolo with structured subjects, flashcards, and guided review workflows.`;
}

function buildStructuredData(
  entity: SeoEntity,
  description: string,
  canonicalUrl: string,
): Array<Record<string, unknown>> {
  const webpage: Record<string, unknown> = {
    '@context': 'https://schema.org',
    '@type': entity.kind === 'subject' ? 'CollectionPage' : 'CollectionPage',
    name: entity.kind === 'subject' ? `${entity.name} Flashcards` : `${entity.name} Collection`,
    description,
    url: canonicalUrl,
    isPartOf: {
      '@type': 'WebSite',
      name: 'Aliolo',
      url: BASE_URL,
    },
  };

  if (entity.kind === 'subject') {
    return [
      webpage,
      {
        '@context': 'https://schema.org',
        '@type': 'LearningResource',
        name: `${entity.name} Flashcards`,
        description,
        url: canonicalUrl,
        learningResourceType: 'Flashcards',
        hasPart: entity.cards
          .filter((card) => card.prompt || card.answer)
          .map((card) => ({
            '@type': 'Question',
            name: card.prompt || 'Study prompt',
            text: card.prompt || 'Study prompt',
            acceptedAnswer: {
              '@type': 'Answer',
              text: card.answer || '',
            },
          })),
      },
    ];
  }

  return [
    webpage,
    {
      '@context': 'https://schema.org',
      '@type': 'ItemList',
      name: `${entity.name} Study Collection`,
      description,
      url: canonicalUrl,
      itemListElement: entity.subjects.map((subject, index) => ({
        '@type': 'ListItem',
        position: index + 1,
        name: subject.name || `Subject ${index + 1}`,
      })),
    },
  ];
}

function buildPreviewHtml(entity: SeoEntity, description: string): string {
  const title =
    entity.kind === 'subject'
      ? `${escapeHtml(entity.name)} flashcards`
      : `${escapeHtml(entity.name)} collection`;

  const previewItems =
    entity.kind === 'subject'
      ? entity.cards
          .filter((card) => card.prompt || card.answer)
          .slice(0, 6)
          .map(
            (card) => `
              <li>
                <strong>${escapeHtml(card.prompt || 'Study prompt')}</strong>
                <span>${escapeHtml(card.answer || 'Open Aliolo to study this card.')}</span>
              </li>`,
          )
          .join('')
      : entity.subjects
          .slice(0, 6)
          .map(
            (subject) => `
              <li>
                <strong>${escapeHtml(subject.name || 'Untitled subject')}</strong>
                <span>${escapeHtml(subject.description || 'Included in this public Aliolo collection.')}</span>
              </li>`,
          )
          .join('');

  const countLabel =
    entity.kind === 'subject'
      ? `${entity.cards.length} preview card${entity.cards.length === 1 ? '' : 's'}`
      : `${entity.subjects.length} included subject${entity.subjects.length === 1 ? '' : 's'}`;

  return `
    <style>
      #aliolo-seo-shell {
        margin: 0 auto;
        padding: 40px 20px 12px;
        max-width: 1100px;
        font-family: "Source Sans 3", system-ui, -apple-system, sans-serif;
        color: #122338;
      }
      #aliolo-seo-shell .aliolo-card {
        border: 1px solid rgba(18, 35, 56, 0.10);
        border-radius: 28px;
        background: rgba(255, 255, 255, 0.96);
        box-shadow: 0 24px 54px rgba(18, 35, 56, 0.08);
        overflow: hidden;
      }
      #aliolo-seo-shell .aliolo-hero {
        padding: 28px 28px 18px;
        background:
          radial-gradient(circle at top left, rgba(24, 95, 144, 0.10), transparent 28rem),
          linear-gradient(180deg, rgba(249, 252, 253, 0.98) 0%, rgba(238, 245, 248, 0.98) 100%);
      }
      #aliolo-seo-shell .aliolo-kicker {
        display: inline-flex;
        padding: 8px 12px;
        border-radius: 999px;
        background: rgba(24, 95, 144, 0.10);
        color: #185f90;
        font-size: 13px;
        font-weight: 700;
        letter-spacing: 0.08em;
        text-transform: uppercase;
      }
      #aliolo-seo-shell h1 {
        margin: 16px 0 12px;
        font-family: "Manrope", system-ui, -apple-system, sans-serif;
        font-size: clamp(34px, 5vw, 54px);
        line-height: 1.02;
        letter-spacing: -0.05em;
      }
      #aliolo-seo-shell p {
        margin: 0;
        color: #5f6f85;
        font-size: 18px;
        line-height: 1.6;
      }
      #aliolo-seo-shell .aliolo-meta {
        margin-top: 18px;
        color: #185f90;
        font-size: 14px;
        font-weight: 700;
      }
      #aliolo-seo-shell .aliolo-body {
        padding: 24px 28px 28px;
      }
      #aliolo-seo-shell h2 {
        margin: 0 0 14px;
        font-family: "Manrope", system-ui, -apple-system, sans-serif;
        font-size: 24px;
        line-height: 1.1;
      }
      #aliolo-seo-shell ul {
        list-style: none;
        padding: 0;
        margin: 0;
        display: grid;
        gap: 12px;
      }
      #aliolo-seo-shell li {
        padding: 16px 18px;
        border: 1px solid rgba(18, 35, 56, 0.10);
        border-radius: 18px;
        background: rgba(255, 255, 255, 0.94);
      }
      #aliolo-seo-shell li strong {
        display: block;
        margin-bottom: 6px;
        color: #122338;
        font-size: 16px;
      }
      #aliolo-seo-shell li span {
        color: #5f6f85;
        font-size: 15px;
      }
      #aliolo-seo-shell .aliolo-cta {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        margin-top: 18px;
        min-height: 48px;
        padding: 0 18px;
        border-radius: 14px;
        background: linear-gradient(135deg, #185f90, #0d476d);
        color: #fff;
        font-weight: 700;
        text-decoration: none;
      }
      @media (max-width: 700px) {
        #aliolo-seo-shell {
          padding: 20px 14px 8px;
        }
        #aliolo-seo-shell .aliolo-hero,
        #aliolo-seo-shell .aliolo-body {
          padding-left: 20px;
          padding-right: 20px;
        }
      }
    </style>
    <main id="aliolo-seo-shell" aria-label="Aliolo public page preview">
      <article class="aliolo-card">
        <section class="aliolo-hero">
          <span class="aliolo-kicker">${entity.kind === 'subject' ? 'Public flashcards' : 'Public collection'}</span>
          <h1>${title}</h1>
          <p>${escapeHtml(description)}</p>
          <div class="aliolo-meta">${escapeHtml(countLabel)} available before the full app loads.</div>
        </section>
        <section class="aliolo-body">
          <h2>${entity.kind === 'subject' ? 'Preview cards' : 'Included subjects'}</h2>
          <ul>${previewItems || '<li><strong>Preview unavailable</strong><span>Open Aliolo to load the full study page.</span></li>'}</ul>
          <a class="aliolo-cta" href="/login">Open Aliolo</a>
        </section>
      </article>
    </main>`;
}

function replaceOrInsert(
  html: string,
  pattern: RegExp,
  replacement: string,
  insertionMarker: string,
): string {
  if (pattern.test(html)) {
    return html.replace(pattern, replacement);
  }

  return html.replace(insertionMarker, `${replacement}${insertionMarker}`);
}

function escapeHtml(unsafe: string): string {
  return unsafe
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}
