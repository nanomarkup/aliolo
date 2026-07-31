import { describe, expect, it } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';
import { generateSeoHtml } from '../src/utils/seo';

function uniqueId(prefix: string) {
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

describe('SEO and crawlability', () => {
  it('redirects the public HTTP origin to HTTPS', async () => {
    const res = await app.request('http://aliolo.com/pricing?source=test', {}, env);

    expect(res.status).toBe(308);
    expect(res.headers.get('location')).toBe('https://aliolo.com/pricing?source=test');
  });

  it('allows local HTTP development', async () => {
    const res = await app.request('http://localhost/robots.txt', {}, env);
    expect(res.status).toBe(200);
  });

  it('renders the public landing page with conversion and accessibility essentials', async () => {
    const res = await app.request('https://aliolo.com/', {}, env);
    const html = await res.text();

    expect(res.status).toBe(200);
    expect(html).toContain('<link rel="canonical" href="https://aliolo.com/">');
    expect(html).toContain('<link rel="icon" type="image/webp" href="/app_icon.webp">');
    expect(html).toContain('<link rel="manifest" href="/manifest.json">');
    expect(html).toContain('https://aliolo.com/aliolo-social-preview.png');
    expect(html).toContain('<meta property="og:image:width" content="1200">');
    expect(html).toContain('<meta property="og:image:height" content="630">');
    expect(html).toContain('<a class="skip-link" href="#main-content">Skip to content</a>');
    expect(html).toContain('id="main-content"');
    expect(html).toContain('src="/landing-product-preview.jpg"');
    expect(html).toContain('href="/login" class="btn btn-primary">Create free account</a>');
    expect(html).toContain('href="/?login=1" class="btn btn-secondary">Log in</a>');
    expect(html).toContain('aria-label="View monthly plan details"');
    expect(html).not.toContain('payment partners');
    expect(html).not.toContain('Paddle review');
    expect(html).not.toContain('crawlable learning content');
  });

  it('serves robots.txt with sitemap and crawl directives', async () => {
    const res = await app.request('https://aliolo.com/robots.txt', {}, env);
    const text = await res.text();

    expect(res.status).toBe(200);
    expect(text).toContain('Sitemap: https://aliolo.com/sitemap.xml');
    expect(text).toContain('Disallow: /api/');
    expect(text).not.toContain('Disallow: /pay');
    expect(text).not.toContain('Disallow: /login');
  });

  it('builds a sitemap with accurate dates and no ignored hints', async () => {
    const res = await app.request('https://aliolo.com/sitemap.xml', {}, env);
    const xml = await res.text();

    expect(res.status).toBe(200);
    expect(res.headers.get('content-type')).toContain('application/xml');
    expect(xml).toContain('<loc>https://aliolo.com/</loc>');
    expect(xml).toContain('<lastmod>2026-08-01</lastmod>');
    expect(xml).not.toContain('<changefreq>');
    expect(xml).not.toContain('<priority>');
  });

  it('renders pricing page with social metadata', async () => {
    const res = await app.request('https://aliolo.com/pricing', {}, env);
    const html = await res.text();

    expect(res.status).toBe(200);
    expect(html).toContain('<meta property="og:title" content="Aliolo Premium Pricing">');
    expect(html).toContain('<meta name="twitter:title" content="Aliolo Premium Pricing">');
    expect(html).toContain('<script type="application/ld+json">');
  });

  it('builds subject SEO html with route metadata and preview shell', async () => {
    const pillarId = 1001;
    const ownerId = uniqueId('user');
    const subjectId = uniqueId('subject');

    await env.DB.prepare(
      `INSERT OR IGNORE INTO pillars (id, name, names, description, descriptions)
       VALUES (?, 'Languages', '{}', 'Language pillar', '{}')`,
    ).bind(pillarId).run();

    await env.DB.prepare(
      `INSERT INTO profiles (id, username, email, password_hash, main_pillar_id)
       VALUES (?, 'seo-user', ?, 'hash', ?)`,
    ).bind(ownerId, `${ownerId}@example.com`, pillarId).run();

    await env.DB.prepare(
      `INSERT INTO subjects (id, pillar_id, owner_id, is_public, name, names, description, descriptions)
       VALUES (?, ?, ?, 1, 'Medical Spanish', '{}', 'Flashcards for medical Spanish vocabulary.', '{}')`,
    ).bind(subjectId, pillarId, ownerId).run();

    await env.DB.prepare(
      `INSERT INTO cards (id, subject_id, owner_id, prompt, answer)
       VALUES (?, ?, ?, 'How do you say heart?', 'corazon')`,
    ).bind(uniqueId('card'), subjectId, ownerId).run();

    const html = await generateSeoHtml(
      env.DB,
      `/subject/${subjectId}`,
      '<html><head><title>Aliolo App</title><meta name="description" content="App"></head><body><script src="/flutter_bootstrap.js"></script></body></html>',
    );

    expect(html).toBeTruthy();
    expect(html).toContain('<title>Medical Spanish Flashcards | Aliolo</title>');
    expect(html).toContain(`<link rel="canonical" href="https://aliolo.com/subject/${subjectId}">`);
    expect(html).toContain('https://aliolo.com/aliolo-social-preview.png');
    expect(html).toContain('<meta property="og:image:width" content="1200">');
    expect(html).toContain('How do you say heart?');
    expect(html).toContain('Open Aliolo');
  });

  it('builds collection SEO html with route metadata and included subjects', async () => {
    const pillarId = 1002;
    const ownerId = uniqueId('user');
    const collectionId = uniqueId('collection');
    const subjectId = uniqueId('subject');

    await env.DB.prepare(
      `INSERT OR IGNORE INTO pillars (id, name, names, description, descriptions)
       VALUES (?, 'Science', '{}', 'Science pillar', '{}')`,
    ).bind(pillarId).run();

    await env.DB.prepare(
      `INSERT INTO profiles (id, username, email, password_hash, main_pillar_id)
       VALUES (?, 'seo-collection-user', ?, 'hash', ?)`,
    ).bind(ownerId, `${ownerId}@example.com`, pillarId).run();

    await env.DB.prepare(
      `INSERT INTO subjects (id, pillar_id, owner_id, is_public, name, names, description, descriptions)
       VALUES (?, ?, ?, 1, 'Basic Anatomy', '{}', 'Foundational anatomy terms.', '{}')`,
    ).bind(subjectId, pillarId, ownerId).run();

    await env.DB.prepare(
      `INSERT INTO collections (id, pillar_id, owner_id, is_public, name, names, description, descriptions)
       VALUES (?, ?, ?, 1, 'Exam Prep Set', '{}', 'A public anatomy review collection.', '{}')`,
    ).bind(collectionId, pillarId, ownerId).run();

    await env.DB.prepare(
      `INSERT INTO collection_items (id, collection_id, subject_id)
       VALUES (?, ?, ?)`,
    ).bind(uniqueId('item'), collectionId, subjectId).run();

    const html = await generateSeoHtml(
      env.DB,
      `/collection/${collectionId}`,
      '<html><head><title>Aliolo App</title><meta name="description" content="App"></head><body><script src="/flutter_bootstrap.js"></script></body></html>',
    );

    expect(html).toBeTruthy();
    expect(html).toContain('<title>Exam Prep Set Collection | Aliolo</title>');
    expect(html).toContain(`<link rel="canonical" href="https://aliolo.com/collection/${collectionId}">`);
    expect(html).toContain('Basic Anatomy');
  });

  it('returns 404 for missing public SEO routes', async () => {
    const res = await app.request('https://aliolo.com/subject/does-not-exist', {}, env);
    expect(res.status).toBe(404);
  });
});
