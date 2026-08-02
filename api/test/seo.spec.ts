import { describe, expect, it } from 'vitest';
import { env } from 'cloudflare:test';
import app from '../src/index';
import { generateSeoHtml } from '../src/utils/seo';
import landingHtml from '../../web/landing.html?raw';
import pricingHtml from '../../web/pricing.html?raw';
import privacyHtml from '../../web/privacy.html?raw';
import termsHtml from '../../web/terms.html?raw';
import refundHtml from '../../web/refund.html?raw';
import payHtml from '../../web/pay.html?raw';
import indexHtml from '../../web/index.html?raw';

const mockEnv = {
  ...env,
  ASSETS: {
    fetch: async (request: Request) => {
      const url = new URL(request.url);
      let filepath = url.pathname;
      
      const SUPPORTED_LANGS = [
        "en", "id", "bg", "cs", "da", "de", "et", "es", "fr", "ga", "hr", "it", "lv", "lt", 
        "hu", "mt", "nl", "pl", "pt", "ro", "sk", "sl", "fi", "sv", "tl", "vi", "tr", "el", 
        "uk", "ar", "hi", "zh", "ja", "ko"
      ];
      const parts = filepath.split('/');
      if (parts.length > 2 && SUPPORTED_LANGS.includes(parts[1])) {
        filepath = '/' + parts.slice(2).join('/');
      } else if (parts.length === 2 && SUPPORTED_LANGS.includes(parts[1])) {
        filepath = '/';
      }

      let html = '';
      if (filepath === '/landing.html' || filepath === '/' || filepath === '/landing') {
        html = landingHtml;
      } else if (filepath === '/pricing.html' || filepath === '/pricing') {
        html = pricingHtml;
      } else if (filepath === '/privacy.html' || filepath === '/privacy') {
        html = privacyHtml;
      } else if (filepath === '/terms.html' || filepath === '/terms') {
        html = termsHtml;
      } else if (filepath === '/refund.html' || filepath === '/refund') {
        html = refundHtml;
      } else if (filepath === '/pay.html' || filepath === '/pay') {
        html = payHtml;
      } else if (filepath === '/index.html') {
        html = indexHtml;
      } else {
        return new Response('Not Found', { status: 404 });
      }
      return new Response(html, {
        status: 200,
        headers: { 'Content-Type': 'text/html;charset=UTF-8' }
      });
    }
  }
};

function uniqueId(prefix: string) {
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

describe('SEO and crawlability', () => {
  it('redirects the public HTTP origin to HTTPS', async () => {
    const res = await app.request('http://aliolo.com/pricing?source=test', {}, mockEnv);

    expect(res.status).toBe(308);
    expect(res.headers.get('location')).toBe('https://aliolo.com/pricing?source=test');
  });

  it('allows local HTTP development', async () => {
    const res = await app.request('http://localhost/robots.txt', {}, mockEnv);
    expect(res.status).toBe(200);
  });

  it('renders the public landing page with conversion and accessibility essentials', async () => {
    const res = await app.request('https://aliolo.com/', {}, mockEnv);
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
    expect(html).toContain('href="/login?login=1" class="btn btn-secondary">Log in</a>');
    expect(html).toContain('aria-label="View monthly plan details"');
    expect(html).not.toContain('payment partners');
    expect(html).not.toContain('Paddle review');
    expect(html).not.toContain('crawlable learning content');
  });

  it('serves robots.txt with sitemap and crawl directives', async () => {
    const res = await app.request('https://aliolo.com/robots.txt', {}, mockEnv);
    const text = await res.text();

    expect(res.status).toBe(200);
    expect(text).toContain('Sitemap: https://aliolo.com/sitemap.xml');
    expect(text).toContain('Disallow: /api/');
    expect(text).not.toContain('Disallow: /pay');
    expect(text).not.toContain('Disallow: /login');
  });

  it('builds a sitemap with accurate dates and no ignored hints', async () => {
    const res = await app.request('https://aliolo.com/sitemap.xml', {}, mockEnv);
    const xml = await res.text();

    expect(res.status).toBe(200);
    expect(res.headers.get('content-type')).toContain('application/xml');
    expect(xml).toContain('<loc>https://aliolo.com/</loc>');
    expect(xml).toContain('<lastmod>2026-08-01</lastmod>');
    expect(xml).not.toContain('<changefreq>');
    expect(xml).not.toContain('<priority>');
  });

  it('renders pricing page with social metadata', async () => {
    const res = await app.request('https://aliolo.com/pricing', {}, mockEnv);
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
    const res = await app.request('https://aliolo.com/subject/does-not-exist', {}, mockEnv);
    expect(res.status).toBe(404);
  });

  it('redirects to preferred language based on Accept-Language header', async () => {
    const res = await app.request('https://aliolo.com/privacy', {
      headers: {
        'Accept-Language': 'es-MX,es;q=0.9,en;q=0.8'
      }
    }, mockEnv);

    expect(res.status).toBe(307);
    expect(res.headers.get('location')).toBe('/es/privacy');
    expect(res.headers.get('set-cookie')).toContain('aliolo_lang=es');
  });

  it('redirects to preferred language based on aliolo_lang cookie', async () => {
    const res = await app.request('https://aliolo.com/terms', {
      headers: {
        'Cookie': 'aliolo_lang=de'
      }
    }, mockEnv);

    expect(res.status).toBe(307);
    expect(res.headers.get('location')).toBe('/de/terms');
  });

  it('sets aliolo_lang cookie when visiting localized page directly', async () => {
    const res = await app.request('https://aliolo.com/fr/refund', {}, mockEnv);
    expect(res.status).toBe(200);
    expect(res.headers.get('set-cookie')).toContain('aliolo_lang=fr');
  });

  it('does not redirect search engine bots', async () => {
    const res = await app.request('https://aliolo.com/pricing', {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
        'Accept-Language': 'es-ES,es;q=0.9'
      }
    }, mockEnv);

    expect(res.status).toBe(200);
  });

  it('redirects /en and /en/:page to their clean counterparts', async () => {
    const resRoot = await app.request('https://aliolo.com/en', {}, mockEnv);
    expect(resRoot.status).toBe(301);
    expect(resRoot.headers.get('location')).toBe('/');

    const resPrivacy = await app.request('https://aliolo.com/en/privacy', {}, mockEnv);
    expect(resPrivacy.status).toBe(301);
    expect(resPrivacy.headers.get('location')).toBe('/privacy');

    const resUnknown = await app.request('https://aliolo.com/en/unknown', {}, mockEnv);
    expect(resUnknown.status).toBe(301);
    expect(resUnknown.headers.get('location')).toBe('/');
  });

  it('serves the SPA app shell for localized app paths', async () => {
    const resLogin = await app.request('https://aliolo.com/es/login', {}, mockEnv);
    expect(resLogin.status).toBe(200);
    const html = await resLogin.text();
    expect(html).toContain('flutter_bootstrap.js');
  });

  it('applies Cache-Control no-cache, must-revalidate to critical files', async () => {
    const customAssetsEnv = {
      ...env,
      ASSETS: {
        fetch: async (request: Request) => {
          const url = new URL(request.url);
          const filepath = url.pathname;
          return new Response('dummy content', {
            status: 200,
            headers: { 'Content-Type': filepath.endsWith('.js') ? 'application/javascript' : 'text/plain' }
          });
        }
      }
    };

    // Test a .nano file
    const resNano = await app.request('https://aliolo.com/assets/translations/en.nano', {}, customAssetsEnv);
    expect(resNano.status).toBe(200);
    expect(resNano.headers.get('Cache-Control')).toBe('no-cache, must-revalidate');

    // Test service worker js
    const resSW = await app.request('https://aliolo.com/flutter_service_worker.js', {}, customAssetsEnv);
    expect(resSW.status).toBe(200);
    expect(resSW.headers.get('Cache-Control')).toBe('no-cache, must-revalidate');

    // Test landing page HTML
    const resHtml = await app.request('https://aliolo.com/privacy', {}, mockEnv);
    expect(resHtml.status).toBe(200);
    expect(resHtml.headers.get('Cache-Control')).toBe('no-cache, must-revalidate');
  });

});
