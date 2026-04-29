import { OpenAPIHono } from '@hono/zod-openapi';
import { swaggerUI } from '@hono/swagger-ui';
import { cors } from 'hono/cors';
import { isbot } from 'isbot';
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
    --ink: #112034;
    --muted: #5f6c81;
    --brand: #175f90;
    --brand-strong: #0d476d;
    --accent: #d67a2d;
    --accent-soft: rgba(214, 122, 45, 0.12);
    --surface: rgba(255, 255, 255, 0.96);
    --page: #eef4f7;
    --line: rgba(17, 32, 52, 0.10);
    --line-strong: rgba(23, 95, 144, 0.18);
    --shadow: 0 22px 58px rgba(17, 32, 52, 0.08);
  }
  * { box-sizing: border-box; }
  html { scroll-behavior: smooth; }
  body {
    margin: 0;
    color: var(--ink);
    font-family: "Source Sans 3", system-ui, -apple-system, sans-serif;
    line-height: 1.6;
    background:
      radial-gradient(circle at top left, rgba(23, 95, 144, 0.11), transparent 28rem),
      radial-gradient(circle at top right, rgba(214, 122, 45, 0.10), transparent 24rem),
      linear-gradient(180deg, #f9fcfd 0%, var(--page) 100%);
  }
  a { color: var(--brand); font-weight: 700; text-decoration: none; }
  a:hover { text-decoration: underline; }
  .shell { width: min(1100px, calc(100% - 40px)); margin: 0 auto; }
  header {
    position: sticky;
    top: 0;
    z-index: 20;
    padding: 20px 0;
    backdrop-filter: blur(18px);
    background: rgba(249, 252, 253, 0.88);
    border-bottom: 1px solid rgba(17, 32, 52, 0.06);
  }
  .brand {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 20px;
    flex-wrap: wrap;
  }
  .brand-name {
    display: inline-flex;
    align-items: center;
    gap: 12px;
    font-family: "Manrope", system-ui, -apple-system, sans-serif;
    font-size: 27px;
    font-weight: 800;
    line-height: 1;
    letter-spacing: -0.04em;
    color: var(--brand);
    text-transform: lowercase;
  }
  .brand-name:hover { text-decoration: none; }
  .brand-name img {
    width: 46px;
    height: 46px;
  }
  nav { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; }
  nav a {
    color: var(--ink);
    font-size: 15px;
    font-weight: 600;
    padding: 10px 14px;
    border: 1px solid transparent;
    border-radius: 999px;
    transition: background 0.18s ease, border-color 0.18s ease, transform 0.18s ease;
  }
  nav a:hover {
    border-color: var(--line);
    background: rgba(255, 255, 255, 0.84);
    transform: translateY(-1px);
    text-decoration: none;
  }
  nav a.active {
    border-color: var(--line-strong);
    background: rgba(23, 95, 144, 0.08);
    color: var(--brand);
    text-decoration: none;
  }
  main { padding: 34px 0 78px; }
  .hero {
    display: grid;
    grid-template-columns: minmax(0, 1fr) 290px;
    gap: 28px;
    align-items: stretch;
    margin-bottom: 28px;
  }
  h1 {
    margin: 0;
    font-family: "Manrope", system-ui, sans-serif;
    font-size: clamp(34px, 5vw, 52px);
    font-weight: 800;
    line-height: 1.02;
    letter-spacing: -0.05em;
    color: var(--ink);
  }
  .subtitle {
    margin: 14px 0 0;
    color: var(--muted);
    font-size: 18px;
    max-width: 760px;
  }
  .eyebrow {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 14px;
    padding: 8px 12px;
    border-radius: 999px;
    background: rgba(23, 95, 144, 0.10);
    color: var(--brand);
    font-size: 13px;
    font-weight: 700;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }
  .meta {
    padding: 22px;
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 24px;
    font-size: 14px;
    color: var(--muted);
    box-shadow: var(--shadow);
  }
  .meta strong { color: var(--ink); font-weight: 600; }
  .content {
    background: var(--surface);
    border: 1px solid var(--line);
    border-radius: 28px;
    padding: clamp(24px, 4vw, 48px);
    box-shadow: var(--shadow);
  }
  h2 {
    margin: 34px 0 12px;
    font-family: "Manrope", system-ui, sans-serif;
    font-size: 24px;
    font-weight: 800;
    line-height: 1.1;
    letter-spacing: -0.03em;
    color: var(--ink);
  }
  h2:first-child { margin-top: 0; }
  p { margin: 12px 0; font-size: 17px; }
  ul { padding-left: 24px; margin: 12px 0; }
  li { margin: 8px 0; font-size: 17px; }
  .notice {
    margin: 24px 0;
    padding: 18px 20px;
    border-radius: 18px;
    background: rgba(23, 95, 144, 0.06);
    border: 1px solid rgba(23, 95, 144, 0.10);
    color: var(--ink);
    font-size: 14px;
  }
  .plans {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 18px;
    margin: 24px 0;
  }
  .plan {
    padding: 26px;
    border: 1px solid var(--line);
    border-radius: 24px;
    background: rgba(255, 255, 255, 0.96);
    box-shadow: 0 16px 34px rgba(17, 32, 52, 0.05);
  }
  .plan h2 { margin-top: 0; color: var(--ink); font-size: 22px; }
  .price {
    font-family: "Manrope", system-ui, sans-serif;
    font-size: 38px;
    font-weight: 800;
    color: var(--brand);
    margin: 8px 0 16px;
    letter-spacing: -0.05em;
  }
  .tag {
    display: inline-flex;
    margin-bottom: 12px;
    padding: 6px 11px;
    border-radius: 999px;
    background: var(--accent-soft);
    color: var(--accent);
    font-size: 12px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 0.08em;
  }
  .comparison-card {
    margin-top: 28px;
    padding: 28px;
    border-radius: 28px;
    border: 1px solid var(--line);
    background: rgba(255, 255, 255, 0.96);
    box-shadow: 0 16px 34px rgba(17, 32, 52, 0.05);
  }
  .comparison-card h2 {
    margin-top: 0;
  }
  .comparison-card p {
    color: var(--muted);
  }
  .comparison-table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 18px;
  }
  .comparison-table th,
  .comparison-table td {
    padding: 14px 10px;
    border-bottom: 1px solid var(--line);
    text-align: center;
    font-size: 15px;
  }
  .comparison-table th:first-child,
  .comparison-table td:first-child {
    text-align: left;
    width: 52%;
  }
  .comparison-table th {
    color: var(--muted);
    font-weight: 700;
  }
  .comparison-table td:first-child {
    color: var(--ink);
    font-weight: 600;
  }
  .comparison-table tr:last-child td {
    border-bottom: none;
  }
  .comparison-check {
    color: var(--brand);
    font-weight: 800;
    font-size: 18px;
  }
  .comparison-check.pro {
    color: #0f9d58;
  }
  .comparison-cross {
    color: #c4ccd8;
    font-weight: 800;
    font-size: 18px;
  }
  .comparison-note {
    margin-top: 18px;
    color: var(--muted);
    font-size: 15px;
  }
  @media (max-width: 760px) {
    .shell { width: min(100% - 28px, 1100px); }
    header { padding: 16px 0; }
    .hero, .plans { grid-template-columns: 1fr; }
    .hero { gap: 16px; }
    nav { gap: 6px; }
    nav a { padding: 9px 12px; }
    main { padding-top: 24px; }
  }
`;

function legalPage(args: {
  title: string;
  subtitle: string;
  active: 'privacy' | 'terms' | 'refund' | 'pricing';
  updated: string;
  path: string;
  body: string;
}) {
  const nav = [
    ['home', 'Home', '/'],
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
  <link rel="canonical" href="https://aliolo.com${args.path}">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Manrope:wght@500;600;700;800&family=Source+Sans+3:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>${legalStyles}</style>
</head>
<body>
  <header>
    <div class="shell brand">
      <a class="brand-name" href="/" aria-label="Aliolo home">
        <img src="/app_icon.webp" alt="Aliolo Logo" />
        aliolo
      </a>
      <nav aria-label="Legal page navigation">
        ${nav.map(([key, label, href]) => `<a class="${args.active === key ? 'active' : ''}" href="${href}">${label}</a>`).join('')}
      </nav>
    </div>
  </header>
  <main class="shell">
    <section class="hero">
      <div>
        <div class="eyebrow">Legal information</div>
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
  path: '/privacy',
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
  path: '/terms',
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
  path: '/refund',
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
  path: '/pricing',
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

    <div class="comparison-card">
      <h2>Free vs Premium Comparison</h2>
      <p>This table matches the current app experience and makes the premium upgrade easier to evaluate at a glance.</p>
      <table class="comparison-table" aria-label="Aliolo free and premium feature comparison">
        <thead>
          <tr>
            <th>Feature</th>
            <th>Free</th>
            <th>Premium</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>Full library</td>
            <td><span class="comparison-check">✓</span></td>
            <td><span class="comparison-check pro">✓</span></td>
          </tr>
          <tr>
            <td>Spaced repetition</td>
            <td><span class="comparison-cross">✕</span></td>
            <td><span class="comparison-check pro">✓</span></td>
          </tr>
          <tr>
            <td>Creation</td>
            <td><span class="comparison-cross">✕</span></td>
            <td><span class="comparison-check pro">✓</span></td>
          </tr>
          <tr>
            <td>Testing</td>
            <td><span class="comparison-cross">✕</span></td>
            <td><span class="comparison-check pro">✓</span></td>
          </tr>
          <tr>
            <td>Autoplay</td>
            <td><span class="comparison-cross">✕</span></td>
            <td><span class="comparison-check pro">✓</span></td>
          </tr>
          <tr>
            <td>Private mode</td>
            <td><span class="comparison-cross">✕</span></td>
            <td><span class="comparison-check pro">✓</span></td>
          </tr>
          <tr>
            <td>Customize</td>
            <td><span class="comparison-cross">✕</span></td>
            <td><span class="comparison-check pro">✓</span></td>
          </tr>
        </tbody>
      </table>
      <div class="comparison-note">
        Premium unlocks the full study workflow: adaptive review, creation tools, advanced testing, autoplay controls, private organization, and deeper personalization.
      </div>
    </div>

    <h2>Platform Price Differences</h2>
    <p>Prices and offers may vary between web checkout, Google Play, Apple App Store, countries, currencies, and limited-time promotions. The final checkout screen controls the actual price and renewal terms for your purchase.</p>

    <h2>Related Policies</h2>
    <p>Before subscribing, review the <a href="/terms">Subscription Terms</a>, <a href="/refund">Refund Policy</a>, and <a href="/privacy">Privacy Policy</a>.</p>
  `,
});

function buildPayHtml(clientToken?: string) {
  const tokenJson = JSON.stringify(clientToken ?? '');
  const hasToken = Boolean(clientToken);

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Aliolo Checkout</title>
  <meta name="description" content="Secure checkout for Aliolo Premium subscriptions.">
  <meta name="robots" content="noindex,nofollow">
  <link rel="canonical" href="https://aliolo.com/pay">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Manrope:wght@500;600;700;800&family=Source+Sans+3:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>
    :root {
      color-scheme: light;
      --ink: #122338;
      --muted: #5f6f85;
      --brand: #185f90;
      --brand-strong: #0d476d;
      --accent: #d97728;
      --line: rgba(18, 35, 56, 0.12);
      --surface: rgba(255, 255, 255, 0.96);
      --page: #eef5f8;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      font-family: "Source Sans 3", system-ui, -apple-system, sans-serif;
      color: var(--ink);
      background:
        radial-gradient(circle at top left, rgba(24, 95, 144, 0.10), transparent 28rem),
        radial-gradient(circle at top right, rgba(217, 119, 40, 0.10), transparent 24rem),
        linear-gradient(180deg, #f9fcfd 0%, var(--page) 100%);
    }
    a { color: var(--brand); text-decoration: none; font-weight: 700; }
    a:hover { text-decoration: underline; }
    .shell {
      width: min(1100px, calc(100% - 32px));
      margin: 0 auto;
    }
    header {
      padding: 22px 0;
      border-bottom: 1px solid rgba(18, 35, 56, 0.06);
      background: rgba(249, 252, 253, 0.88);
      backdrop-filter: blur(14px);
    }
    .brand {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 18px;
      flex-wrap: wrap;
    }
    .brand-name {
      display: inline-flex;
      align-items: center;
      gap: 12px;
      color: var(--brand);
      font-family: "Manrope", system-ui, sans-serif;
      font-size: 27px;
      font-weight: 800;
      letter-spacing: -0.04em;
      text-transform: lowercase;
    }
    .brand-name:hover { text-decoration: none; }
    .brand-name img {
      width: 44px;
      height: 44px;
    }
    nav {
      display: flex;
      gap: 10px;
      flex-wrap: wrap;
    }
    nav a {
      color: var(--ink);
      font-size: 15px;
      font-weight: 600;
      padding: 10px 14px;
      border-radius: 999px;
      border: 1px solid transparent;
    }
    nav a:hover {
      background: rgba(255, 255, 255, 0.84);
      border-color: var(--line);
      text-decoration: none;
    }
    main {
      padding: 42px 0 72px;
    }
    .layout {
      display: grid;
      grid-template-columns: minmax(0, 0.92fr) minmax(320px, 0.78fr);
      gap: 24px;
      align-items: start;
    }
    .card {
      padding: 28px;
      border-radius: 28px;
      border: 1px solid var(--line);
      background: var(--surface);
      box-shadow: 0 24px 54px rgba(18, 35, 56, 0.08);
    }
    .eyebrow {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 16px;
      padding: 8px 12px;
      border-radius: 999px;
      background: rgba(24, 95, 144, 0.10);
      color: var(--brand);
      font-size: 13px;
      font-weight: 700;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }
    h1 {
      margin: 0 0 12px;
      font-family: "Manrope", system-ui, sans-serif;
      font-size: clamp(34px, 5vw, 52px);
      line-height: 1.02;
      letter-spacing: -0.04em;
    }
    p {
      margin: 0 0 14px;
      color: var(--muted);
      font-size: 17px;
      line-height: 1.6;
    }
    .status {
      margin-top: 22px;
      padding: 18px 20px;
      border-radius: 18px;
      background: rgba(24, 95, 144, 0.06);
      border: 1px solid rgba(24, 95, 144, 0.12);
      color: var(--ink);
      font-size: 15px;
    }
    .status strong { color: var(--brand); }
    .status.error {
      background: rgba(217, 119, 40, 0.10);
      border-color: rgba(217, 119, 40, 0.16);
    }
    .list {
      display: grid;
      gap: 14px;
      margin-top: 20px;
    }
    .list div {
      padding: 16px 18px;
      border-radius: 18px;
      background: rgba(255, 255, 255, 0.92);
      border: 1px solid var(--line);
    }
    .list strong {
      display: block;
      margin-bottom: 6px;
      color: var(--ink);
      font-size: 15px;
    }
    .checkout-shell {
      min-height: 560px;
      display: grid;
      align-content: start;
      gap: 18px;
    }
    .checkout-target {
      min-height: 450px;
    }
    .fallback {
      display: none;
      padding: 20px;
      border-radius: 20px;
      border: 1px dashed rgba(24, 95, 144, 0.24);
      background: rgba(24, 95, 144, 0.04);
      color: var(--muted);
      font-size: 15px;
    }
    .fallback.visible {
      display: block;
    }
    .links {
      display: flex;
      gap: 14px;
      flex-wrap: wrap;
      margin-top: 10px;
    }
    .links a {
      color: var(--muted);
      font-weight: 600;
    }
    @media (max-width: 920px) {
      .layout {
        grid-template-columns: 1fr;
      }
    }
  </style>
  <script src="https://cdn.paddle.com/paddle/v2/paddle.js"></script>
</head>
<body>
  <header>
    <div class="shell brand">
      <a class="brand-name" href="/" aria-label="Aliolo home">
        <img src="/app_icon.webp" alt="Aliolo logo" />
        aliolo
      </a>
      <nav aria-label="Checkout page navigation">
        <a href="/pricing">Pricing</a>
        <a href="/terms">Terms</a>
        <a href="/privacy">Privacy</a>
        <a href="/refund">Refund</a>
      </nav>
    </div>
  </header>
  <main class="shell">
    <section class="layout">
      <article class="card">
        <div class="eyebrow">Secure checkout</div>
        <h1>Complete your Aliolo Premium purchase.</h1>
        <p>This page is dedicated to Paddle checkout. When a valid Aliolo transaction is passed in, Paddle opens the payment flow automatically and handles taxes, payment methods, receipts, and renewal billing.</p>
        <div class="status" id="checkout-status">
          <strong>Waiting for checkout</strong><br>
          If you opened this page from Aliolo billing, the payment form should appear automatically.
        </div>
        <div class="list">
          <div>
            <strong>Payment support</strong>
            Web payments are processed by Paddle.com as Merchant of Record.
          </div>
          <div>
            <strong>Subscription billing</strong>
            Aliolo Premium renews automatically until canceled. You can cancel later through Paddle or your Aliolo account.
          </div>
          <div>
            <strong>Need policy details?</strong>
            Review pricing, subscription terms, privacy, and refund information before completing your purchase.
          </div>
        </div>
        <div class="links">
          <a href="/pricing">Pricing</a>
          <a href="/terms">Subscription Terms</a>
          <a href="/privacy">Privacy Policy</a>
          <a href="/refund">Refund Policy</a>
        </div>
      </article>
      <aside class="card checkout-shell">
        <div id="checkout-fallback" class="fallback">Checkout could not be started on this page. Return to Aliolo billing and try again. If the problem persists, contact <a href="mailto:vitalii@nohainc.com">vitalii@nohainc.com</a>.</div>
        <div id="checkout-container" class="checkout-target" aria-live="polite"></div>
      </aside>
    </section>
  </main>
  <script>
    (() => {
      const token = ${tokenJson};
      const statusEl = document.getElementById('checkout-status');
      const fallbackEl = document.getElementById('checkout-fallback');
      const params = new URLSearchParams(window.location.search);
      const transactionId = params.get('_ptxn');

      const setStatus = (title, message, isError = false) => {
        statusEl.classList.toggle('error', isError);
        statusEl.innerHTML = '<strong>' + title + '</strong><br>' + message;
      };

      if (!token) {
        fallbackEl.classList.add('visible');
        setStatus(
          'Checkout is not configured',
          'Aliolo is missing the Paddle client-side token required for the /pay page. Add PADDLE_CLIENT_TOKEN to the Worker environment before using this checkout.',
          true,
        );
        return;
      }

      if (!transactionId) {
        fallbackEl.classList.add('visible');
        setStatus(
          'No checkout transaction found',
          'This page is meant to be opened from an Aliolo billing flow. Open billing in the app and start checkout again.',
          true,
        );
        return;
      }

      try {
        if (token.startsWith('test_')) {
          Paddle.Environment.set('sandbox');
        }

        Paddle.Initialize({
          token,
          eventCallback: function (event) {
            if (event.name === 'checkout.loaded') {
              setStatus('Checkout loaded', 'Paddle is ready. Continue in the payment form on this page.');
            }
            if (event.name === 'checkout.closed') {
              setStatus('Checkout closed', 'The checkout was closed before payment completed. You can return to Aliolo billing and try again.');
            }
            if (event.name === 'checkout.completed') {
              setStatus('Payment submitted', 'Your payment was submitted. Aliolo will unlock premium access after Paddle confirms the subscription.');
            }
            if (event.name === 'checkout.error') {
              fallbackEl.classList.add('visible');
              setStatus('Checkout error', 'Paddle reported an error while loading checkout. Return to billing and try again.', true);
            }
          },
          checkout: {
            settings: {
              displayMode: 'inline',
              frameTarget: 'checkout-container',
              frameInitialHeight: 540,
              frameStyle: 'width: 100%; min-width: 312px; background-color: transparent; border: none;',
              theme: 'light',
              variant: 'one-page',
              showAddTaxId: false,
              allowLogout: true,
            },
          },
        });

        setStatus('Opening checkout', 'Paddle is opening your secure payment form now.');
      } catch (error) {
        fallbackEl.classList.add('visible');
        setStatus(
          'Checkout failed to initialize',
          'Paddle.js could not initialize on this page. Verify the client-side token and retry from Aliolo billing.',
          true,
        );
      }
    })();
  </script>
</body>
</html>`;
}

const landingStyles = `
  :root {
    color-scheme: light;
    --ink: #162235;
    --muted: #5f6f85;
    --brand: #185f90;
    --brand-strong: #0d476d;
    --accent: #d97728;
    --line: rgba(18, 34, 53, 0.10);
    --line-strong: rgba(24, 95, 144, 0.18);
    --surface: #ffffff;
    --surface-soft: #f6fbfd;
    --hero-wash: rgba(24, 95, 144, 0.08);
    --hero-wash-2: rgba(217, 119, 40, 0.09);
    --page: #eef5f8;
  }
  * { box-sizing: border-box; }
  html { scroll-behavior: smooth; }
  body {
    margin: 0;
    color: var(--ink);
    font-family: "Roboto", system-ui, -apple-system, sans-serif;
    line-height: 1.58;
    background:
      radial-gradient(circle at top left, var(--hero-wash), transparent 30rem),
      radial-gradient(circle at top right, var(--hero-wash-2), transparent 28rem),
      linear-gradient(180deg, #f9fcfd 0%, var(--page) 100%);
  }
  a { color: var(--brand); font-weight: 700; text-decoration: none; }
  a:hover { text-decoration: underline; }
  .shell { width: min(1160px, calc(100% - 40px)); margin: 0 auto; }
  header {
    padding: 22px 0;
    position: sticky;
    top: 0;
    z-index: 10;
    backdrop-filter: blur(16px);
    background: rgba(249, 252, 253, 0.88);
    border-bottom: 1px solid rgba(18, 34, 53, 0.06);
  }
  .brand {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 20px;
    flex-wrap: wrap;
  }
  .brand-name {
    display: inline-flex;
    align-items: center;
    gap: 12px;
    font-family: "Poppins", system-ui, sans-serif;
    font-size: 26px;
    font-weight: 600;
    line-height: 1;
    letter-spacing: 0.03em;
    color: var(--brand);
    text-transform: lowercase;
  }
  .brand-name:hover { text-decoration: none; }
  .brand-name img {
    width: 44px;
    height: 44px;
    border-radius: 12px;
  }
  nav {
    display: flex;
    align-items: center;
    gap: 10px;
    flex-wrap: wrap;
  }
  nav a {
    color: var(--ink);
    font-size: 14px;
    font-weight: 500;
    padding: 10px 14px;
    border-radius: 999px;
    border: 1px solid transparent;
    transition: all 0.18s ease;
  }
  nav a:hover {
    text-decoration: none;
    border-color: var(--line);
    background: rgba(255, 255, 255, 0.84);
  }
  .nav-cta {
    border-color: var(--line-strong);
    background: rgba(24, 95, 144, 0.08);
    color: var(--brand);
    font-weight: 700;
  }
  main { padding: 32px 0 80px; }
  .hero {
    display: grid;
    grid-template-columns: minmax(0, 1.1fr) minmax(320px, 0.9fr);
    gap: 34px;
    align-items: stretch;
    margin-bottom: 74px;
  }
  .hero-copy {
    padding: 56px 0 10px;
  }
  .eyebrow {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 8px 12px;
    border-radius: 999px;
    background: rgba(24, 95, 144, 0.10);
    color: var(--brand);
    font-size: 13px;
    font-weight: 700;
    letter-spacing: 0.06em;
    text-transform: uppercase;
  }
  h1 {
    margin: 18px 0 18px;
    font-family: "Poppins", system-ui, sans-serif;
    font-size: clamp(44px, 7vw, 76px);
    line-height: 0.95;
    letter-spacing: -0.05em;
    color: var(--ink);
  }
  .hero p {
    margin: 0;
    font-size: 18px;
    color: var(--muted);
    max-width: 720px;
  }
  .cta-group {
    display: flex;
    gap: 14px;
    flex-wrap: wrap;
    margin-top: 28px;
  }
  .btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-height: 54px;
    padding: 0 24px;
    border-radius: 16px;
    font-weight: 700;
    font-size: 15px;
    transition: transform 0.18s ease, box-shadow 0.18s ease, background 0.18s ease;
    cursor: pointer;
    border: 1px solid transparent;
  }
  .btn:hover {
    transform: translateY(-1px);
    text-decoration: none;
    box-shadow: 0 12px 28px rgba(18, 34, 53, 0.10);
  }
  .btn-primary {
    background: linear-gradient(135deg, var(--brand), var(--brand-strong));
    color: #fff;
  }
  .btn-secondary {
    background: rgba(255, 255, 255, 0.82);
    color: var(--ink);
    border-color: var(--line);
  }
  .proof-row {
    display: flex;
    gap: 22px;
    flex-wrap: wrap;
    margin-top: 28px;
  }
  .proof {
    min-width: 150px;
  }
  .proof strong {
    display: block;
    font-family: "Poppins", system-ui, sans-serif;
    font-size: 28px;
    line-height: 1;
    letter-spacing: -0.04em;
    color: var(--brand);
  }
  .proof span {
    display: block;
    margin-top: 8px;
    color: var(--muted);
    font-size: 13px;
  }
  .hero-panel {
    position: relative;
    padding: 24px;
    border-radius: 30px;
    background: linear-gradient(180deg, rgba(255,255,255,0.96), rgba(243,249,252,0.98));
    border: 1px solid var(--line);
    box-shadow: 0 30px 70px rgba(18, 34, 53, 0.10);
    overflow: hidden;
  }
  .hero-panel::before {
    content: "";
    position: absolute;
    inset: -80px auto auto -80px;
    width: 210px;
    height: 210px;
    border-radius: 50%;
    background: rgba(24, 95, 144, 0.08);
  }
  .panel-card {
    position: relative;
    background: #fff;
    border: 1px solid var(--line);
    border-radius: 24px;
    padding: 22px;
    margin-bottom: 16px;
  }
  .panel-card:last-child { margin-bottom: 0; }
  .panel-label {
    color: var(--accent);
    font-size: 12px;
    font-weight: 800;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }
  .panel-card h3 {
    margin: 10px 0 8px;
    font-size: 22px;
    font-family: "Poppins", system-ui, sans-serif;
    line-height: 1.1;
  }
  .panel-card p {
    margin: 0 0 14px;
    font-size: 14px;
    color: var(--muted);
  }
  .micro-list {
    display: grid;
    gap: 10px;
  }
  .micro-list span {
    display: flex;
    gap: 10px;
    align-items: flex-start;
    color: var(--ink);
    font-size: 14px;
  }
  .micro-list span::before {
    content: "•";
    color: var(--brand);
    font-weight: 900;
  }
  .section {
    margin-bottom: 74px;
  }
  .section-heading {
    max-width: 720px;
    margin-bottom: 26px;
  }
  .section-heading h2 {
    margin: 0 0 10px;
    font-family: "Poppins", system-ui, sans-serif;
    font-size: clamp(28px, 4vw, 40px);
    line-height: 1.05;
    letter-spacing: -0.04em;
  }
  .section-heading p {
    margin: 0;
    color: var(--muted);
    font-size: 17px;
  }
  .feature-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 18px;
  }
  .feature-card {
    background: rgba(255, 255, 255, 0.92);
    padding: 26px;
    border-radius: 26px;
    border: 1px solid var(--line);
    box-shadow: 0 16px 34px rgba(18, 34, 53, 0.05);
  }
  .feature-card h3 {
    margin: 16px 0 8px;
    font-size: 21px;
    font-family: "Poppins", system-ui, sans-serif;
  }
  .feature-card p {
    margin: 0;
    color: var(--muted);
    font-size: 15px;
  }
  .feature-icon {
    width: 46px;
    height: 46px;
    border-radius: 14px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    background: rgba(24, 95, 144, 0.10);
    color: var(--brand);
    font-weight: 900;
    font-size: 18px;
    font-family: "Poppins", system-ui, sans-serif;
  }
  .steps {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 18px;
  }
  .step {
    padding: 24px;
    border-radius: 24px;
    background: linear-gradient(180deg, rgba(255,255,255,0.96), rgba(240,248,251,0.96));
    border: 1px solid var(--line);
  }
  .step strong {
    display: inline-flex;
    width: 36px;
    height: 36px;
    align-items: center;
    justify-content: center;
    border-radius: 999px;
    background: var(--brand);
    color: #fff;
    font-size: 14px;
    margin-bottom: 16px;
  }
  .step h3 {
    margin: 0 0 8px;
    font-size: 20px;
    font-family: "Poppins", system-ui, sans-serif;
  }
  .step p {
    margin: 0;
    color: var(--muted);
  }
  .pricing-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 18px;
  }
  .price-card {
    padding: 28px;
    border-radius: 26px;
    background: rgba(255,255,255,0.96);
    border: 1px solid var(--line);
    position: relative;
  }
  .price-card.featured {
    border-color: var(--line-strong);
    box-shadow: 0 18px 40px rgba(24, 95, 144, 0.12);
    transform: translateY(-4px);
  }
  .price-tag {
    display: inline-flex;
    padding: 6px 10px;
    border-radius: 999px;
    background: rgba(217, 119, 40, 0.10);
    color: var(--accent);
    font-size: 12px;
    font-weight: 800;
    text-transform: uppercase;
    letter-spacing: 0.08em;
  }
  .price-card h3 {
    margin: 16px 0 8px;
    font-family: "Poppins", system-ui, sans-serif;
    font-size: 22px;
  }
  .price-amount {
    margin: 6px 0 12px;
    font-family: "Poppins", system-ui, sans-serif;
    font-size: 38px;
    line-height: 1;
    letter-spacing: -0.05em;
    color: var(--brand);
  }
  .price-card p {
    margin: 0 0 18px;
    color: var(--muted);
  }
  .price-card ul {
    margin: 0;
    padding-left: 18px;
  }
  .price-card li {
    color: var(--ink);
    margin: 8px 0;
  }
  .trust-panel {
    padding: 30px;
    border-radius: 28px;
    background: linear-gradient(180deg, rgba(255,255,255,0.97), rgba(245,250,252,0.97));
    border: 1px solid var(--line);
  }
  .trust-grid {
    display: grid;
    grid-template-columns: 1.15fr 0.85fr;
    gap: 28px;
    align-items: start;
  }
  .trust-panel h2 {
    margin: 0 0 10px;
    font-family: "Poppins", system-ui, sans-serif;
    font-size: 32px;
    line-height: 1.08;
  }
  .trust-panel p {
    margin: 0 0 14px;
    color: var(--muted);
    font-size: 16px;
  }
  .trust-list {
    display: grid;
    gap: 12px;
    margin-top: 18px;
  }
  .trust-list div {
    padding: 14px 16px;
    border-radius: 16px;
    background: rgba(24, 95, 144, 0.06);
    border: 1px solid rgba(24, 95, 144, 0.10);
  }
  .mini-faq {
    display: grid;
    gap: 12px;
  }
  .mini-faq div {
    padding: 16px 18px;
    border-radius: 18px;
    background: #fff;
    border: 1px solid var(--line);
  }
  .mini-faq strong {
    display: block;
    margin-bottom: 6px;
    font-size: 15px;
  }
  footer {
    padding: 56px 0 70px;
    border-top: 1px solid rgba(18, 34, 53, 0.08);
    margin-top: 70px;
  }
  .footer-grid {
    display: grid;
    grid-template-columns: 1.2fr 0.8fr;
    gap: 24px;
    align-items: start;
  }
  .footer-brand {
    display: grid;
    gap: 10px;
  }
  .footer-brand strong {
    font-family: "Poppins", system-ui, sans-serif;
    color: var(--brand);
    font-size: 18px;
  }
  .footer-brand p {
    margin: 0;
    color: var(--muted);
    max-width: 540px;
  }
  .footer-links {
    display: flex;
    gap: 12px;
    flex-wrap: wrap;
    justify-content: flex-end;
  }
  .footer-links a {
    color: var(--muted);
    font-weight: 500;
  }
  .legal-note {
    margin-top: 20px;
    padding: 18px 20px;
    border-radius: 18px;
    background: rgba(255,255,255,0.8);
    border: 1px solid var(--line);
    color: var(--muted);
    font-size: 14px;
  }
  @media (max-width: 980px) {
    .hero,
    .trust-grid,
    .footer-grid,
    .feature-grid,
    .steps,
    .pricing-grid {
      grid-template-columns: 1fr;
    }
    .hero-copy {
      padding-top: 20px;
    }
    .footer-links {
      justify-content: flex-start;
    }
    .price-card.featured {
      transform: none;
    }
  }
  @media (max-width: 640px) {
    .shell { width: min(100% - 28px, 1160px); }
    header { padding: 18px 0; }
    nav { gap: 6px; }
    nav a { padding: 9px 12px; }
    .hero { gap: 20px; margin-bottom: 56px; }
    .cta-group { flex-direction: column; align-items: stretch; }
    .btn { width: 100%; }
    .proof-row { gap: 14px; }
  }
`;

const landingStructuredData = JSON.stringify([
  {
    '@context': 'https://schema.org',
    '@type': 'Organization',
    name: 'Aliolo',
    url: 'https://aliolo.com',
    logo: 'https://aliolo.com/app_icon.webp',
    email: 'vitalii@nohainc.com',
  },
  {
    '@context': 'https://schema.org',
    '@type': 'WebSite',
    name: 'Aliolo',
    url: 'https://aliolo.com',
    description: 'Visual flashcards, spaced repetition, and interactive learning tools for building durable knowledge.',
    inLanguage: 'en',
  },
  {
    '@context': 'https://schema.org',
    '@type': 'SoftwareApplication',
    name: 'Aliolo',
    applicationCategory: 'EducationalApplication',
    operatingSystem: 'Web, Android, iOS',
    offers: [
      {
        '@type': 'Offer',
        name: 'Weekly',
        price: '2.99',
        priceCurrency: 'USD',
      },
      {
        '@type': 'Offer',
        name: 'Monthly',
        price: '8.99',
        priceCurrency: 'USD',
      },
      {
        '@type': 'Offer',
        name: 'Yearly',
        price: '80.99',
        priceCurrency: 'USD',
      },
    ],
    url: 'https://aliolo.com',
    description: 'Aliolo helps learners master subjects with visual flashcards, spaced repetition, testing workflows, and structured study libraries.',
  },
]);

const landingHtml = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Aliolo | Visual Flashcards, Spaced Repetition, and Smarter Study Workflows</title>
  <meta name="description" content="Aliolo helps learners master languages, science, anatomy, exam prep, and curated subjects with visual flashcards, spaced repetition, and interactive test modes.">
  <meta name="robots" content="index,follow,max-image-preview:large,max-snippet:-1,max-video-preview:-1">
  <meta property="og:type" content="website">
  <meta property="og:title" content="Aliolo | Visual Flashcards and Smarter Study Workflows">
  <meta property="og:description" content="Build durable knowledge with visual flashcards, spaced repetition, flexible collections, and test-driven learning.">
  <meta property="og:url" content="https://aliolo.com/">
  <meta property="og:image" content="https://aliolo.com/app_icon.webp">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="Aliolo | Visual Flashcards and Smarter Study Workflows">
  <meta name="twitter:description" content="Master what matters with visual flashcards, spaced repetition, and interactive test modes.">
  <link rel="canonical" href="https://aliolo.com/">
  <script>
    (() => {
      const params = new URLSearchParams(window.location.search);
      if (params.has('login') || params.has('type') || params.has('invite')) {
        window.location.replace('/login' + window.location.search + window.location.hash);
      }
    })();
  </script>
  <style>${landingStyles}</style>
  <script type="application/ld+json">${landingStructuredData}</script>
</head>
<body>
  <header>
    <div class="shell brand">
      <a class="brand-name" href="/" aria-label="Aliolo home">
        <img src="/app_icon.webp" alt="Aliolo logo">
        aliolo
      </a>
      <nav aria-label="Site navigation">
        <a href="/pricing">Pricing</a>
        <a href="/privacy">Privacy</a>
        <a href="/terms">Terms</a>
        <a href="/login" class="nav-cta">Open App</a>
      </nav>
    </div>
  </header>

  <main class="shell">
    <section class="hero">
      <div class="hero-copy">
        <div class="eyebrow">Visual learning platform</div>
        <h1>Turn scattered facts into lasting recall.</h1>
        <p>Aliolo combines visual flashcards, spaced repetition, structured study libraries, and focused test modes so students can learn faster, organize better, and stay consistent across subjects.</p>
        <div class="cta-group">
          <a href="/login" class="btn btn-primary">Start learning</a>
          <a href="/pricing" class="btn btn-secondary">View premium plans</a>
        </div>
        <div class="proof-row" aria-label="Product highlights">
          <div class="proof">
            <strong>Visual</strong>
            <span>Image, audio, and video friendly flashcards for recognition-heavy learning.</span>
          </div>
          <div class="proof">
            <strong>Adaptive</strong>
            <span>Spaced repetition and progress tracking to revisit material at the right time.</span>
          </div>
          <div class="proof">
            <strong>Structured</strong>
            <span>Pillars, folders, subjects, and collections that scale beyond a simple deck.</span>
          </div>
        </div>
      </div>
      <aside class="hero-panel" aria-label="Aliolo study workflow preview">
        <section class="panel-card">
          <div class="panel-label">Learn mode</div>
          <h3>Build recognition before you test recall.</h3>
          <p>Study with rich media and context first, then switch to stricter practice once the concept is familiar.</p>
          <div class="micro-list">
            <span>Visual flashcards for anatomy, languages, sciences, and more</span>
            <span>Clean repetition flow that supports daily learning habits</span>
          </div>
        </section>
        <section class="panel-card">
          <div class="panel-label">Test mode</div>
          <h3>Prove mastery under pressure.</h3>
          <p>Use focused testing sessions to reinforce recall, identify weak spots, and keep progress measurable.</p>
          <div class="micro-list">
            <span>Switch from broad exposure to outcome-driven practice</span>
            <span>Track streaks, XP, and daily completion without losing structure</span>
          </div>
        </section>
      </aside>
    </section>

    <section class="section" id="features">
      <div class="section-heading">
        <h2>Built for real study workflows, not just isolated decks.</h2>
        <p>Aliolo is designed for people who need more than a card stack. It supports discovery, organization, review timing, and long-term subject growth in one system.</p>
      </div>
      <div class="feature-grid">
        <article class="feature-card">
          <div class="feature-icon">VF</div>
          <h3>Visual-first flashcards</h3>
          <p>Support recognition and context with cards that can include images, audio, video, and flexible prompts instead of plain text alone.</p>
        </article>
        <article class="feature-card">
          <div class="feature-icon">LT</div>
          <h3>Learn and test modes</h3>
          <p>Start with guided exposure, then move into tighter assessment flows when you need confident recall instead of passive familiarity.</p>
        </article>
        <article class="feature-card">
          <div class="feature-icon">SR</div>
          <h3>Spaced repetition</h3>
          <p>Review timing adapts to progress so you can reinforce material before it fades rather than cramming everything at once.</p>
        </article>
        <article class="feature-card">
          <div class="feature-icon">OR</div>
          <h3>Structured organization</h3>
          <p>Group material into pillars, folders, subjects, and collections so large libraries stay navigable and useful over time.</p>
        </article>
        <article class="feature-card">
          <div class="feature-icon">CU</div>
          <h3>Curated and custom</h3>
          <p>Use curated subject libraries for fast starts or create your own study system when your goals are niche, professional, or exam-specific.</p>
        </article>
        <article class="feature-card">
          <div class="feature-icon">XP</div>
          <h3>Progress that sticks</h3>
          <p>Daily goals, XP, streaks, and repeatable sessions create enough structure to help retention without turning study into noise.</p>
        </article>
      </div>
    </section>

    <section class="section" id="workflow">
      <div class="section-heading">
        <h2>A clearer path from “I should study” to “I know this.”</h2>
        <p>The product is built around a practical sequence: find the right material, learn with context, then test under tighter constraints.</p>
      </div>
      <div class="steps">
        <article class="step">
          <strong>01</strong>
          <h3>Find or build the right subject.</h3>
          <p>Start from curated material or create your own subject for a personal goal, exam, language track, or professional vocabulary set.</p>
        </article>
        <article class="step">
          <strong>02</strong>
          <h3>Learn with media, structure, and repetition.</h3>
          <p>Study inside organized folders and collections while spaced review keeps important material circulating at the right frequency.</p>
        </article>
        <article class="step">
          <strong>03</strong>
          <h3>Test for retention, not just exposure.</h3>
          <p>Switch into test mode when you need to measure recall, expose weak spots, and convert short-term recognition into durable knowledge.</p>
        </article>
      </div>
    </section>

    <section class="section" id="pricing">
      <div class="section-heading">
        <h2>Simple premium access with room to scale.</h2>
        <p>Choose the plan that matches your timeline. Prices are listed in USD; final billing details, taxes, and local currency may vary by checkout or platform.</p>
      </div>
      <div class="pricing-grid">
        <article class="price-card">
          <span class="price-tag">Flexible</span>
          <h3>Weekly</h3>
          <div class="price-amount">$2.99</div>
          <p>Good for short-term pushes, quick reviews, or exam-week prep.</p>
          <ul>
            <li>Short commitment window</li>
            <li>Fast way to try the premium workflow</li>
            <li>Renews automatically until canceled</li>
          </ul>
        </article>
        <article class="price-card featured">
          <span class="price-tag">Most popular</span>
          <h3>Monthly</h3>
          <div class="price-amount">$8.99</div>
          <p>Balanced access for students building a steady learning habit.</p>
          <ul>
            <li>Best for regular weekly study</li>
            <li>Enough time to organize larger subject libraries</li>
            <li>Renews automatically until canceled</li>
          </ul>
        </article>
        <article class="price-card">
          <span class="price-tag">Best value</span>
          <h3>Yearly</h3>
          <div class="price-amount">$80.99</div>
          <p>Lowest effective monthly cost for learners who want a durable study system.</p>
          <ul>
            <li>Ideal for long-term language and professional study</li>
            <li>Lower cost over time</li>
            <li>Renews automatically until canceled</li>
          </ul>
        </article>
      </div>
    </section>

    <section class="section">
      <div class="trust-panel">
        <div class="trust-grid">
          <div>
            <h2>Clear trust signals for students, reviewers, and payment partners.</h2>
            <p>Aliolo is a live educational product with public legal pages, public pricing, accessible support contact, and a public subject index. That matters for user trust and for partner verification flows such as Paddle review.</p>
            <div class="trust-list">
              <div><strong>Support:</strong> <a href="mailto:vitalii@nohainc.com">vitalii@nohainc.com</a></div>
              <div><strong>Public policies:</strong> Privacy, subscription terms, refund policy, and pricing are all accessible without login.</div>
              <div><strong>Public learning pages:</strong> Selected subject pages are crawlable and expose structured educational content.</div>
            </div>
          </div>
          <div class="mini-faq" aria-label="Mini FAQ">
            <div>
              <strong>Can I use Aliolo without building cards from scratch?</strong>
              Curated subjects and public libraries help you start faster, then expand into your own collections when needed.
            </div>
            <div>
              <strong>How do web payments work?</strong>
              Web orders may be processed by Paddle.com as Merchant of Record, including payment support and applicable tax handling.
            </div>
            <div>
              <strong>Where can I review legal details?</strong>
              Use the footer links for privacy, terms, refunds, and pricing before starting a paid plan.
            </div>
          </div>
        </div>
      </div>
    </section>
  </main>

  <footer>
    <div class="shell">
      <div class="footer-grid">
        <div class="footer-brand">
          <strong>Aliolo</strong>
          <p>Visual flashcards, spaced repetition, flexible subject organization, and focused testing workflows for learners who want structure without friction.</p>
        </div>
        <div class="footer-links">
          <a href="/privacy">Privacy Policy</a>
          <a href="/terms">Subscription Terms</a>
          <a href="/refund">Refund Policy</a>
          <a href="/pricing">Pricing</a>
          <a href="mailto:vitalii@nohainc.com">Support</a>
        </div>
      </div>
      <div class="legal-note">
        <strong>Merchant of Record:</strong> Our order process may be conducted by Paddle.com, our online reseller and Merchant of Record for web orders. Paddle handles payment processing, payment-related customer service, and returns for those orders.
      </div>
    </div>
  </footer>
</body>
</html>`;

const appShellHtml = `<!DOCTYPE html>
<html>
<head>
  <base href="/">
  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="description" content="Aliolo app for visual learning, structured flashcards, and focused study workflows.">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="Aliolo">
  <link rel="apple-touch-icon" href="/icons/Icon-192.png">
  <link rel="icon" type="image/webp" href="/app_icon.webp">
  <link rel="manifest" href="/manifest.json">
  <title>Aliolo App</title>
  <script>
    if ('serviceWorker' in navigator) {
      window.addEventListener('load', function () {
        navigator.serviceWorker.ready.then(function (reg) {
          reg.onupdatefound = function () {
            const newWorker = reg.installing;
            if (!newWorker) return;
            newWorker.onstatechange = function () {
              if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
                window.postMessage('flutter-app-update-available', '*');
              }
            };
          };
        });
      });
    }
  </script>
</head>
<body>
  <script src="/flutter_bootstrap.js" async></script>
</body>
</html>`;

function shouldServeAppShell(pathname: string) {
  return (
    pathname === '/login' ||
    pathname.startsWith('/subject/') ||
    pathname.startsWith('/collection/') ||
    pathname.startsWith('/goals/')
  );
}

app.get('/terms', (c) => c.html(termsHtml));
app.get('/privacy', (c) => c.html(privacyHtml));
app.get('/refund', (c) => c.html(refundHtml));
app.get('/pricing', (c) => c.html(pricingHtml));
app.get('/pay', (c) => c.html(buildPayHtml(c.env.PADDLE_CLIENT_TOKEN)));

// Landing Page / SPA Routing
app.get('/', async (c, next) => {
    const url = new URL(c.req.url);
    const user = c.get('user');

    if (!user && !url.searchParams.has('login')) {
        return c.html(landingHtml);
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
    
    // If the asset is not found (404), only known app routes should bootstrap the SPA shell.
    if (assetResponse.status === 404 && !url.pathname.includes('.') && shouldServeAppShell(url.pathname)) {
        let htmlBody = appShellHtml;

        const userAgent = c.req.header('user-agent') || '';
        if (isbot(userAgent) || url.pathname.startsWith('/subject/') || url.pathname.startsWith('/goals/')) {
            const seoHtml = await generateSeoHtml(c.env.DB, url.pathname, htmlBody);
            if (seoHtml) {
                htmlBody = seoHtml;
            }
        }

        const newHeaders = new Headers(assetResponse.headers);
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
