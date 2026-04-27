import { OpenAPIHono } from '@hono/zod-openapi';
import { swaggerUI } from '@hono/swagger-ui';
import { cors } from 'hono/cors';
import { isbot } from 'isbot';
import { initializeLucia } from './auth';
import type { AppEnv } from './types';
import { generateSeoHtml } from './utils/seo';

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
import adminRouter from './routes/admin';
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
app.route('/api/admin', adminRouter);
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

// Public compliance pages for checkout, app store review, and buyer support.
const legalStyles = `
  :root {
    color-scheme: light;
    --brand: #1d4289;
    --brand-soft: rgba(29, 66, 137, 0.08);
    --ink: rgba(0, 0, 0, 0.87);
    --muted: rgba(0, 0, 0, 0.6);
    --surface: #ffffff;
    --bg: #F1F5F9;
    --line: rgba(0, 0, 0, 0.05);
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    color: var(--ink);
    font-family: "Roboto", system-ui, -apple-system, sans-serif;
    line-height: 1.55;
    background-color: var(--bg);
  }
  a { color: var(--brand); font-weight: 700; text-decoration: none; }
  a:hover { text-decoration: underline; }
  .shell { width: min(1040px, calc(100% - 48px)); margin: 0 auto; }
  header {
    padding: 24px 0;
  }
  .brand { display: flex; align-items: center; justify-content: space-between; gap: 20px; flex-wrap: wrap; }
  .brand-name { 
    display: flex;
    flex-direction: column;
    align-items: center;
    font-family: "Poppins", system-ui, -apple-system, sans-serif; 
    font-size: 28px; 
    font-weight: 600; 
    line-height: 1;
    letter-spacing: 2px; 
    color: var(--brand); 
    text-transform: lowercase;
  }
  .brand-name:hover {
    text-decoration: none;
  }
  .brand-name img {
    height: 44px;
    margin-bottom: 2px;
    border-radius: 10px;
  }
  nav { display: flex; gap: 10px; flex-wrap: wrap; }
  nav a {
    color: var(--ink);
    font-family: "Roboto", system-ui, sans-serif;
    font-size: 14px;
    padding: 8px 16px;
    border: 1px solid var(--line);
    border-radius: 999px;
    background: var(--surface);
    transition: all 0.2s ease;
  }
  nav a.active, nav a:hover { 
    border-color: var(--brand); 
    background: var(--brand-soft); 
    color: var(--brand);
    text-decoration: none;
  }
  main { padding: 24px 0 56px; }
  .hero {
    display: grid;
    grid-template-columns: minmax(0, 1fr) 280px;
    gap: 28px;
    align-items: center;
    margin-bottom: 24px;
  }
  h1 {
    margin: 0;
    font-family: "Poppins", system-ui, sans-serif;
    font-size: clamp(32px, 5vw, 48px);
    font-weight: 700;
    line-height: 1.1;
    color: var(--brand);
  }
  .subtitle { margin: 12px 0 0; color: var(--muted); font-size: 16px; max-width: 720px; }
  .meta {
    padding: 20px;
    background: var(--surface);
    border-radius: 22px;
    font-size: 14px;
    color: var(--muted);
  }
  .meta strong { color: var(--ink); font-weight: 600; }
  .content {
    background: var(--surface);
    border-radius: 22px;
    padding: clamp(24px, 4vw, 48px);
  }
  h2 {
    margin: 32px 0 12px;
    font-size: 20px;
    font-weight: 700;
    color: var(--brand);
  }
  h2:first-child { margin-top: 0; }
  p { margin: 12px 0; }
  ul { padding-left: 24px; margin: 12px 0; }
  li { margin: 8px 0; }
  .notice {
    margin: 24px 0;
    padding: 16px 20px;
    border-radius: 14px;
    background: var(--brand-soft);
    color: var(--brand);
    font-size: 14px;
  }
  .plans {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 16px;
    margin: 24px 0;
  }
  .plan {
    padding: 24px;
    border: 1px solid var(--line);
    border-radius: 22px;
    background: var(--surface);
  }
  .plan h2 { margin-top: 0; color: var(--ink); font-size: 18px; }
  .price {
    font-family: "Poppins", system-ui, sans-serif;
    font-size: 28px;
    font-weight: 700;
    color: var(--brand);
    margin: 8px 0 16px;
  }
  .tag {
    display: inline-flex;
    margin-bottom: 12px;
    padding: 4px 10px;
    border-radius: 8px;
    background: rgba(216, 121, 45, 0.1);
    color: #d8792d;
    font-size: 12px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
  @media (max-width: 760px) {
    .hero, .plans { grid-template-columns: 1fr; }
    .hero { gap: 16px; }
    main { padding-top: 16px; }
  }
`;

function legalPage(args: {
  title: string;
  subtitle: string;
  active: 'privacy' | 'terms' | 'refund' | 'pricing';
  updated: string;
  body: string;
}) {
  const nav = [
    ['privacy', 'Privacy', '/privacy'],
    ['terms', 'Terms', '/terms'],
    ['refund', 'Refunds', '/refund'],
    ['pricing', 'Pricing', '/pricing'],
  ] as const;

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${args.title}</title>
  <meta name="description" content="${args.subtitle}">
  <style>${legalStyles}</style>
</head>
<body>
  <header>
    <div class="shell brand">
      <a class="brand-name" href="/" aria-label="Aliolo home">
        <img src="/app_icon.webp" alt="Aliolo Logo" />
        aliolo
      </a>
      <nav aria-label="Legal and pricing pages">
        ${nav.map(([key, label, href]) => `<a class="${args.active === key ? 'active' : ''}" href="${href}">${label}</a>`).join('')}
      </nav>
    </div>
  </header>
  <main class="shell">
    <section class="hero">
      <div>
        <h1>${args.title}</h1>
        <p class="subtitle">${args.subtitle}</p>
      </div>
      <aside class="meta">
        <strong>Last updated</strong><br>
        ${args.updated}<br><br>
        <strong>Support</strong><br>
        <a href="mailto:vitalii@nohainc.com">vitalii@nohainc.com</a>
      </aside>
    </section>
    <article class="content">
      ${args.body}
    </article>
  </main>
</body>
</html>`;
}

const privacyHtml = legalPage({
  title: 'Aliolo Privacy Policy',
  active: 'privacy',
  updated: 'April 28, 2026',
  subtitle: 'How Aliolo collects, uses, stores, and protects account, learning, and payment-related information.',
  body: `
    <h2>Information We Collect</h2>
    <p>We collect the information needed to operate Aliolo, including account details such as email address, username, password authentication data, avatar settings, preferences, and profile settings.</p>
    <p>We also store learning activity such as subjects, folders, collections, cards, progress, streaks, daily goals, test and learn settings, feedback, and basic app usage events needed to provide the learning experience.</p>

    <h2>How We Use Information</h2>
    <p>We use this information to create and secure your account, synchronize your learning data, personalize your study experience, provide premium access, respond to support requests, improve the app, and prevent misuse or service abuse.</p>

    <h2>Payments and Subscriptions</h2>
    <p>Aliolo does not directly store complete payment card details. Web payments are processed by Paddle, and mobile purchases may be processed by Google Play or Apple App Store when those purchase channels are available.</p>
    <p>For subscription access, we may store payment-provider identifiers, product identifiers, subscription status, renewal period dates, and related webhook or transaction metadata. This lets us activate, renew, cancel, or restore premium access.</p>

    <h2>Third-Party Services</h2>
    <p>We use service providers for hosting, infrastructure, storage, analytics or operational logs, authentication, and payments. These providers process information only as needed to provide their services to Aliolo.</p>
    <div class="notice"><strong>Paddle notice:</strong> Our order process may be conducted by Paddle.com, our online reseller and Merchant of Record. Paddle handles payment processing, tax calculation where applicable, payment security, and payment-related customer service.</div>

    <h2>Cookies and Local Storage</h2>
    <p>Aliolo may use cookies, session identifiers, browser storage, or similar technologies to keep you signed in, remember preferences, secure the service, and operate the web app.</p>

    <h2>Data Retention and Deletion</h2>
    <p>We keep account and learning data while your account is active or as needed to provide the service, comply with legal obligations, resolve disputes, prevent abuse, and maintain transaction records. You may request account deletion or data-related support by contacting us.</p>

    <h2>Children and Education Use</h2>
    <p>Aliolo is an educational product. If a parent, guardian, or school believes that a child has provided personal information without appropriate permission, contact us so we can review and take appropriate action.</p>

    <h2>Security</h2>
    <p>We use reasonable technical and organizational safeguards to protect personal information. No online service can guarantee perfect security, but we work to limit access and protect data from unauthorized use.</p>

    <h2>Your Choices and Rights</h2>
    <p>Depending on your location, you may have rights to access, correct, delete, export, or restrict use of your personal information. Contact us at <a href="mailto:vitalii@nohainc.com">vitalii@nohainc.com</a> to make a request.</p>
  `,
});

const termsHtml = legalPage({
  title: 'Aliolo Subscription Terms',
  active: 'terms',
  updated: 'April 28, 2026',
  subtitle: 'The rules for Aliolo accounts, premium access, subscription billing, cancellation, and acceptable use.',
  body: `
    <h2>Using Aliolo</h2>
    <p>Aliolo provides visual learning tools, curated educational content, flashcards, progress tracking, and premium learning features. You are responsible for keeping your account credentials secure and for using the service lawfully.</p>

    <h2>Premium Access</h2>
    <p>Premium access unlocks paid features shown in the app or on the pricing page. Available features may change as the product improves, but active subscribers will continue to receive access to the paid Aliolo experience during their valid subscription period.</p>

    <h2>Billing and Renewal</h2>
    <p>Subscriptions renew automatically unless canceled before the end of the current billing period. Prices, billing cadence, taxes, local currency conversion, and renewal rules are shown at checkout and may vary by purchase channel, region, platform, or active offer.</p>
    <div class="notice"><strong>Paddle notice:</strong> For web purchases, our order process may be conducted by Paddle.com. Paddle.com is the Merchant of Record for those orders and provides payment-related customer service, tax handling, and returns processing.</div>

    <h2>Cancellation</h2>
    <p>You can cancel according to the rules of the purchase channel you used. Cancellation stops future renewal. Unless the purchase channel states otherwise, paid access remains available until the end of the current billing period.</p>

    <h2>Refunds</h2>
    <p>Refunds are handled according to our <a href="/refund">Refund Policy</a>, the purchase channel rules, and applicable consumer law. App store purchases are normally handled by the relevant app store.</p>

    <h2>Acceptable Use</h2>
    <p>You may not misuse Aliolo, interfere with the service, attempt unauthorized access, scrape or copy content at scale, reverse engineer protected parts of the app, upload unlawful material, or use the service in a way that harms other users or Aliolo.</p>

    <h2>Content and Availability</h2>
    <p>Aliolo may update, add, remove, or reorganize subjects, cards, features, and design. We aim to keep the service reliable, but availability can be affected by maintenance, third-party providers, network issues, or product changes.</p>

    <h2>Disclaimer and Liability</h2>
    <p>Aliolo is provided as an educational and study-support tool. We do not guarantee specific learning, exam, professional, or financial outcomes. To the maximum extent permitted by law, Aliolo is provided without warranties beyond those required by applicable law.</p>

    <h2>Changes to These Terms</h2>
    <p>We may update these terms to reflect product, legal, billing, or operational changes. The current version is published on this page.</p>
  `,
});

const refundHtml = legalPage({
  title: 'Aliolo Refund Policy',
  active: 'refund',
  updated: 'April 28, 2026',
  subtitle: 'How refunds, cancellations, chargebacks, and payment support work for Aliolo Premium.',
  body: `
    <h2>Overview</h2>
    <p>Aliolo Premium is a digital subscription. Because premium access can be activated immediately, purchases are generally final once the subscription is active and used, except where this policy, the purchase channel, or applicable law provides otherwise.</p>

    <h2>7-Day Refund Window</h2>
    <p>If you accidentally purchased a web subscription or have a technical issue that prevents you from using premium features, you may request a refund within 7 days of the initial purchase. Include the account email, order details, and a short description of the issue.</p>

    <h2>No Prorated Mid-Cycle Refunds</h2>
    <p>We do not generally provide prorated refunds for cancellations after the initial refund window. If you cancel after that period, you will normally keep premium access until the end of the paid billing period.</p>

    <h2>Purchase Channel Rules</h2>
    <p>Refunds for purchases made through Google Play or Apple App Store must usually be requested through the relevant app store. Those platforms apply their own refund rules and review process.</p>
    <div class="notice"><strong>Paddle notice:</strong> For web orders, Paddle.com may act as Merchant of Record. Paddle handles payment-related customer service, tax handling, and returns processing for those orders.</div>

    <h2>How to Request a Refund</h2>
    <p>For web orders, contact Paddle buyer support using the order information from your receipt, or contact Aliolo support at <a href="mailto:vitalii@nohainc.com">vitalii@nohainc.com</a>. We may direct payment-specific requests to Paddle when Paddle is the Merchant of Record.</p>

    <h2>Chargebacks and Abuse</h2>
    <p>If a payment is reversed, disputed, refunded, or identified as fraudulent, Aliolo may suspend or remove premium access associated with that transaction.</p>
  `,
});

const pricingHtml = legalPage({
  title: 'Aliolo Premium Pricing',
  active: 'pricing',
  updated: 'April 28, 2026',
  subtitle: 'Simple subscription options for unlocking the full Aliolo visual learning experience.',
  body: `
    <div class="plans">
      <section class="plan">
        <span class="tag">Flexible</span>
        <h2>Weekly</h2>
        <div class="price">$2.99</div>
        <p>Per week. Useful for short-term studying, review, or exam preparation.</p>
      </section>
      <section class="plan">
        <span class="tag">Popular</span>
        <h2>Monthly</h2>
        <div class="price">$8.99</div>
        <p>Per month. Best for consistent learning without a long commitment.</p>
      </section>
      <section class="plan">
        <span class="tag">Best value</span>
        <h2>Yearly</h2>
        <div class="price">$80.99</div>
        <p>Per year. Lower effective monthly cost for long-term learners.</p>
      </section>
    </div>

    <h2>What Premium Includes</h2>
    <ul>
      <li>Full access to premium curated subjects and learning libraries.</li>
      <li>Advanced spaced repetition and progress tracking features.</li>
      <li>Custom flashcard, subject, folder, and collection creation where available.</li>
      <li>Interactive learn and test modes, including autoplay settings.</li>
      <li>Private learning organization features for personal study workflows.</li>
    </ul>

    <h2>Billing Details</h2>
    <p>Prices are listed in USD for this public pricing page. Checkout may show local currency, taxes, and final billing details depending on your location, payment method, and purchase channel.</p>
    <p>Subscriptions renew automatically until canceled. You can cancel according to the rules of the channel where you purchased. Access normally continues until the end of the paid billing period.</p>

    <div class="notice"><strong>Paddle notice:</strong> Web orders may be processed by Paddle.com, our online reseller and Merchant of Record. Paddle may calculate and collect applicable taxes and provide payment-related buyer support.</div>

    <h2>Platform Price Differences</h2>
    <p>Prices and offers may vary between web checkout, Google Play, Apple App Store, countries, currencies, and limited-time promotions. The final checkout screen controls the actual price and renewal terms for your purchase.</p>

    <h2>Related Policies</h2>
    <p>Before subscribing, review the <a href="/terms">Subscription Terms</a>, <a href="/refund">Refund Policy</a>, and <a href="/privacy">Privacy Policy</a>.</p>
  `,
});

app.get('/terms', (c) => c.html(termsHtml));
app.get('/privacy', (c) => c.html(privacyHtml));
app.get('/refund', (c) => c.html(refundHtml));
app.get('/pricing', (c) => c.html(pricingHtml));

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
        
        let htmlBody = await indexResponse.text();
        
        // SEO & Performance Interception (Items 1, 2, 4, 5)
        const userAgent = c.req.header('user-agent') || '';
        // Only run heavy DB queries for bots OR for specific content routes to provide a skeleton screen
        if (isbot(userAgent) || url.pathname.startsWith('/subject/') || url.pathname.startsWith('/goals/')) {
            const seoHtml = await generateSeoHtml(c.env.DB, url.pathname, htmlBody);
            if (seoHtml) {
                htmlBody = seoHtml;
            }
        }

        // Ensure index.html is returned with 200 even if original request was 404
        const newHeaders = new Headers(indexResponse.headers);
        newHeaders.delete('content-length'); // Body size changed
        newHeaders.set('content-type', 'text/html;charset=UTF-8');

        return new Response(htmlBody, {
            status: 200,
            headers: newHeaders,
        });
    }
    
    return assetResponse;
});

export default app;
