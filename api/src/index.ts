import { OpenAPIHono } from '@hono/zod-openapi';
import { swaggerUI } from '@hono/swagger-ui';
import { cors } from 'hono/cors';
import { initializeLucia } from './auth';
import type { AppEnv } from './types';

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
import localizationRouter from './routes/localization';
import analyticsRouter from './routes/analytics';
import storageRouter from './routes/storage';

const app = new OpenAPIHono<AppEnv>();

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
app.route('/api/analytics', analyticsRouter);
app.route('/api', subjectsRouter);
app.route('/api', feedbacksRouter);
app.route('/api', localizationRouter);
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
    
    // If the asset is not found (404), and it doesn't look like a file (no extension),
    // serve index.html for SPA routing.
    if (assetResponse.status === 404 && !url.pathname.includes('.')) {
        const indexRequest = new Request(new URL('/', url).toString(), c.req.raw);
        const indexResponse = await c.env.ASSETS.fetch(indexRequest);
        // Ensure index.html is returned with 200 even if original request was 404
        return new Response(indexResponse.body, {
            status: 200,
            headers: indexResponse.headers,
        });
    }
    
    return assetResponse;
});

export default app;
