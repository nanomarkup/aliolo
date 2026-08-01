import { OpenAPIHono } from '@hono/zod-openapi';
import { swaggerUI } from '@hono/swagger-ui';
import { cors } from 'hono/cors';
import { isbot } from 'isbot';
import { getCookie, setCookie } from 'hono/cookie';
import { initializeLucia } from './auth';
import type { AppEnv } from './types';
import { generateSeoHtml } from './utils/seo';
import { generateSitemapXml } from './utils/sitemap';

import authRouter from './routes/auth';
import pillarsRouter from './routes/pillars';
import subjectsRouter from './routes/subjects';
import cardsRouter from './routes/cards';
import foldersRouter from './routes/folders';
import collectionsRouter from './routes/collections';
import leaderboardRouter from './routes/leaderboard';
import progressRouter from './routes/progress';
import feedbacksRouter from './routes/feedbacks';
import friendshipsRouter from './routes/friendships';
import subscriptionsRouter from './routes/subscriptions';
import adminRouter from './routes/admin';
import analyticsRouter from './routes/analytics';
import storageRouter from './routes/storage';

const app = new OpenAPIHono<AppEnv>();

// Keep one canonical, secure origin for users and search engines. Cloudflare
// forwards the original request scheme to the Worker, so this also covers the
// custom production domain without affecting local HTTP development.
app.use('*', async (c, next) => {
  const url = new URL(c.req.url);
  if (url.protocol === 'http:' && url.hostname !== 'localhost' && url.hostname !== '127.0.0.1') {
    url.protocol = 'https:';
    return c.redirect(url.toString(), 308);
  }
  return next();
});

app.use('*', cors({
    origin: (origin) => origin,
    credentials: true,
}));

// Lucia Auth Middleware
app.use("*", async (c, next) => {
	const lucia = initializeLucia(c.env.DB);
	let sessionId = lucia.readSessionCookie(c.req.header("Cookie") ?? "");
    
    // Fallback to custom header for Web environments where manual Cookie setting is restricted
    if (!sessionId) {
        sessionId = c.req.header("X-Session-Id") ?? null;
    }

	if (!sessionId) {
		c.set("user", null);
		c.set("session", null);
		return next();
	}

	const { session, user } = await lucia.validateSession(sessionId);
	if (session && session.fresh) {
		c.header("Set-Cookie", lucia.createSessionCookie(session.id).serialize(), { append: true });
	}
	if (!session) {
		c.header("Set-Cookie", lucia.createBlankSessionCookie().serialize(), { append: true });
	}
	c.set("user", user);
	c.set("session", session);
	return next();
});

app.route('/api/auth', authRouter);
app.route('/api/pillars', pillarsRouter);
app.route('/api/friendships', friendshipsRouter);
app.route('/api/cards', cardsRouter);
app.route('/api/folders', foldersRouter);
app.route('/api/collections', collectionsRouter);
app.route('/api/leaderboard', leaderboardRouter);
app.route('/api/progress', progressRouter);
app.route('/api/subscriptions', subscriptionsRouter);
app.route('/api/admin', adminRouter);
app.route('/api/analytics', analyticsRouter);
app.route('/api', subjectsRouter);
app.route('/api', feedbacksRouter);
app.route('/', storageRouter);

// Protect OpenAPI documentation
const protectDocs = async (c: any, next: any) => {
  const url = new URL(c.req.url);
  const isLocal = url.hostname === 'localhost' || url.hostname === '127.0.0.1';
  if (!isLocal) {
    return c.text('Not Found', 404);
  }
  await next();
};

app.use('/openapi.json', protectDocs);
app.use('/api/docs*', protectDocs);

// OpenAPI documentation
app.doc('/openapi.json', {
  openapi: '3.0.0',
  info: {
    title: 'Aliolo API',
    version: '1.0.0',
    description: 'API for Aliolo - Your Logic Ally for visual learning.',
  },
});

// Swagger UI
app.get('/api/docs', swaggerUI({ url: '/openapi.json' }));

const SUPPORTED_LANGS = [
  "en", "id", "bg", "cs", "da", "de", "et", "es", "fr", "ga", "hr", "it", "lv", "lt", 
  "hu", "mt", "nl", "pl", "pt", "ro", "sk", "sl", "fi", "sv", "tl", "vi", "tr", "el", 
  "uk", "ar", "hi", "zh", "ja", "ko"
];

function cleanAppPathname(pathname: string): string {
  const parts = pathname.split('/');
  if (parts.length > 2 && SUPPORTED_LANGS.includes(parts[1])) {
    return '/' + parts.slice(2).join('/');
  }
  if (parts.length === 2 && SUPPORTED_LANGS.includes(parts[1])) {
    return '/';
  }
  return pathname;
}

function getPreferredLanguage(acceptLanguageHeader: string | undefined): string {
  if (!acceptLanguageHeader) return 'en';
  const tags = acceptLanguageHeader.split(',')
    .map(part => {
      const [lang, qVal] = part.split(';');
      let q = 1;
      if (qVal && qVal.startsWith('q=')) {
        q = parseFloat(qVal.substring(2)) || 0;
      }
      return { lang: lang.trim().split('-')[0].toLowerCase(), q };
    })
    .sort((a, b) => b.q - a.q);

  for (const tag of tags) {
    if (SUPPORTED_LANGS.includes(tag.lang)) {
      return tag.lang;
    }
  }
  return 'en';
}

const serveAsset = async (c: any, filepath: string) => {
  if (!c.env.ASSETS) {
    return c.text('Not Found', 404);
  }
  const url = new URL(filepath, c.req.url);
  const response = await c.env.ASSETS.fetch(new Request(url.toString(), c.req.raw));
  if (response.status === 404) {
    return c.text('Not Found', 404);
  }
  return response;
};

const renderStaticPage = async (c: any, page: string, lang: string = 'en') => {
  const targetLang = SUPPORTED_LANGS.includes(lang) ? lang : 'en';
  const filepath = targetLang === 'en' ? `/${page}` : `/${targetLang}/${page}`;
  
  if (page === 'pay') {
    const res = await serveAsset(c, filepath);
    if (res.status === 404) return res;
    let html = await res.text();
    html = html.replace('{{PADDLE_CLIENT_TOKEN}}', JSON.stringify(c.env.PADDLE_CLIENT_TOKEN || ''));
    return c.html(html);
  }
  
  return serveAsset(c, filepath);
};

const handleCleanStaticPageRoute = async (c: any, page: string) => {
  const userAgent = c.req.header('User-Agent');
  if (userAgent && isbot(userAgent)) {
    return renderStaticPage(c, page, 'en');
  }

  let lang = getCookie(c, 'aliolo_lang');
  if (!lang || !SUPPORTED_LANGS.includes(lang)) {
    lang = getPreferredLanguage(c.req.header('Accept-Language'));
  }

  if (lang !== 'en') {
    setCookie(c, 'aliolo_lang', lang, {
      path: '/',
      maxAge: 31536000,
      sameSite: 'Lax',
      secure: true
    });
    return c.redirect(`/${lang}/${page}`, 307);
  }

  setCookie(c, 'aliolo_lang', 'en', {
    path: '/',
    maxAge: 31536000,
    sameSite: 'Lax',
    secure: true
  });
  return renderStaticPage(c, page, 'en');
};

const handleLocalizedStaticPageRoute = async (c: any, page: string) => {
  const lang = c.req.param('lang');
  if (SUPPORTED_LANGS.includes(lang) && lang !== 'en') {
    setCookie(c, 'aliolo_lang', lang, {
      path: '/',
      maxAge: 31536000,
      sameSite: 'Lax',
      secure: true
    });
  }
  return renderStaticPage(c, page, lang);
};

app.get('/en', (c) => c.redirect('/', 301));
app.get('/en/:page', (c) => {
  const page = c.req.param('page');
  const allowedPages = ['privacy', 'terms', 'refund', 'pricing', 'pay'];
  if (allowedPages.includes(page)) {
    return c.redirect(`/${page}`, 301);
  }
  return c.redirect('/', 301);
});

app.get('/privacy', (c) => handleCleanStaticPageRoute(c, 'privacy'));
app.get('/:lang/privacy', (c) => handleLocalizedStaticPageRoute(c, 'privacy'));

app.get('/terms', (c) => handleCleanStaticPageRoute(c, 'terms'));
app.get('/:lang/terms', (c) => handleLocalizedStaticPageRoute(c, 'terms'));

app.get('/refund', (c) => handleCleanStaticPageRoute(c, 'refund'));
app.get('/:lang/refund', (c) => handleLocalizedStaticPageRoute(c, 'refund'));

app.get('/pricing', (c) => handleCleanStaticPageRoute(c, 'pricing'));
app.get('/:lang/pricing', (c) => handleLocalizedStaticPageRoute(c, 'pricing'));

app.get('/pay', (c) => handleCleanStaticPageRoute(c, 'pay'));
app.get('/:lang/pay', (c) => handleLocalizedStaticPageRoute(c, 'pay'));

app.get('/robots.txt', (c) =>
  c.text(
    `User-agent: *\nAllow: /\nDisallow: /api/\n\nSitemap: https://aliolo.com/sitemap.xml\n`,
    200,
    {
      'Content-Type': 'text/plain; charset=UTF-8',
      'Cache-Control': 'public, max-age=86400',
    },
  ),
);

// Landing Page / SPA Routing
app.get('/', async (c, next) => {
  const url = new URL(c.req.url);
  const user = c.get('user');

  if (!user && !url.searchParams.has('login')) {
    const userAgent = c.req.header('User-Agent');
    if (userAgent && isbot(userAgent)) {
      return renderStaticPage(c, 'landing', 'en');
    }

    let lang = getCookie(c, 'aliolo_lang');
    if (!lang || !SUPPORTED_LANGS.includes(lang)) {
      lang = getPreferredLanguage(c.req.header('Accept-Language'));
    }

    if (lang !== 'en') {
      setCookie(c, 'aliolo_lang', lang, {
        path: '/',
        maxAge: 31536000,
        sameSite: 'Lax',
        secure: true
      });
      return c.redirect(`/${lang}`, 307);
    }

    setCookie(c, 'aliolo_lang', 'en', {
      path: '/',
      maxAge: 31536000,
      sameSite: 'Lax',
      secure: true
    });
    return renderStaticPage(c, 'landing', 'en');
  }
  
  return next();
});

app.get('/:lang', async (c, next) => {
  const lang = c.req.param('lang');
  if (!SUPPORTED_LANGS.includes(lang) || lang === 'en') {
    return next();
  }
  const url = new URL(c.req.url);
  const user = c.get('user');

  setCookie(c, 'aliolo_lang', lang, {
    path: '/',
    maxAge: 31536000,
    sameSite: 'Lax',
    secure: true
  });

  if (!user && !url.searchParams.has('login')) {
    return renderStaticPage(c, 'landing', lang);
  }
  
  return next();
});

app.get('/sitemap.xml', async (c) => {
    const xml = await generateSitemapXml(c.env.DB, 'https://aliolo.com');
    return c.text(xml, 200, {
        'Content-Type': 'application/xml',
        'Cache-Control': 'public, max-age=86400'
    });
});

function shouldServeAppShell(pathname: string) {
  const cleanPath = cleanAppPathname(pathname);
  return (
    cleanPath === '/login' ||
    cleanPath.startsWith('/subject/') ||
    cleanPath.startsWith('/collection/') ||
    cleanPath.startsWith('/goals/')
  );
}

function isPublicSeoPath(pathname: string) {
  const cleanPath = cleanAppPathname(pathname);
  return (
    cleanPath.startsWith('/subject/') ||
    cleanPath.startsWith('/collection/') ||
    cleanPath.startsWith('/goals/')
  );
}

function buildPublicNotFoundHtml(pathname: string) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Page not found | Aliolo</title>
  <meta name="description" content="The requested Aliolo public page could not be found.">
  <meta name="robots" content="noindex,nofollow">
  <link rel="canonical" href="https://aliolo.com${pathname}">
  <style>
    body {
      margin: 0;
      min-height: 100vh;
      display: grid;
      place-items: center;
      padding: 24px;
      background: linear-gradient(180deg, #f9fcfd 0%, #eef5f8 100%);
      color: #122338;
      font-family: "Source Sans 3", system-ui, -apple-system, sans-serif;
    }
    main {
      max-width: 760px;
      padding: 32px;
      border-radius: 28px;
      border: 1px solid rgba(18, 35, 56, 0.10);
      background: rgba(255, 255, 255, 0.96);
      box-shadow: 0 24px 54px rgba(18, 35, 56, 0.08);
    }
    h1 {
      margin: 0 0 12px;
      font-family: "Manrope", system-ui, -apple-system, sans-serif;
      font-size: clamp(32px, 5vw, 48px);
      line-height: 1.02;
      letter-spacing: -0.04em;
    }
    p {
      margin: 0 0 12px;
      color: #5f6f85;
      font-size: 18px;
      line-height: 1.6;
    }
    a {
      display: inline-flex;
      margin-top: 14px;
      min-height: 48px;
      align-items: center;
      padding: 0 18px;
      border-radius: 14px;
      background: linear-gradient(135deg, #185f90, #0d476d);
      color: #fff;
      text-decoration: none;
      font-weight: 700;
    }
  </style>
</head>
<body>
  <main>
    <h1>Page not found</h1>
    <p>The requested Aliolo public page does not exist or is no longer available.</p>
    <p>Use the public landing page to open the app, browse pricing, or return to a supported study route.</p>
    <a href="/">Return to Aliolo</a>
  </main>
</body>
</html>`;
}

// Fallback to Static Assets or SPA index.html
app.get('*', async (c) => {
    const url = new URL(c.req.url);
    // Ignore API routes for asset serving
    if (url.pathname.startsWith('/api')) {
        return c.text('Not Found', 404);
    }

    if (!c.env.ASSETS) {
        return c.text('Not Found', 404);
    }

    // Try to fetch the specific asset
    const assetResponse = await c.env.ASSETS.fetch(c.req.raw);
    
    // If the asset is not found (404), only known app routes should bootstrap
    // the Flutter shell. web/index.html is the sole app-shell source.
    if (assetResponse.status === 404 && !url.pathname.includes('.') && shouldServeAppShell(url.pathname)) {
        const indexUrl = new URL('/index.html', c.req.url);
        const appShellResponse = await c.env.ASSETS.fetch(
            new Request(indexUrl.toString(), { headers: c.req.raw.headers }),
        );
        if (!appShellResponse.ok) {
            return c.text('Not Found', 404);
        }

        let htmlBody = await appShellResponse.text();

        const userAgent = c.req.header('user-agent') || '';
        const cleanPath = cleanAppPathname(url.pathname);
        if (isbot(userAgent) || isPublicSeoPath(url.pathname)) {
            const seoHtml = await generateSeoHtml(c.env.DB, cleanPath, htmlBody);
            if (seoHtml) {
                htmlBody = seoHtml;
            } else if (isPublicSeoPath(url.pathname)) {
                return c.html(buildPublicNotFoundHtml(url.pathname), 404);
            }
        }

        const newHeaders = new Headers(appShellResponse.headers);
        newHeaders.delete('content-length');
        newHeaders.set('content-type', 'text/html;charset=UTF-8');

        return new Response(htmlBody, {
            status: 200,
            headers: newHeaders,
        });
    }
    
    return assetResponse;
});

export default app;
