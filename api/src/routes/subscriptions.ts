import { OpenAPIHono } from '@hono/zod-openapi';
import { generateId } from 'lucia';
import type { AppEnv } from '../types';

const router = new OpenAPIHono<AppEnv>();

router.get('/', async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    try {
        const result = await c.env.DB.prepare(
            'SELECT * FROM user_subscriptions WHERE user_id = ?'
        ).bind(user.id).first();
        
        return c.json(result);
    } catch (e: any) {
        return c.json({ error: e.message }, 500);
    }
});

router.post('/verify', async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    // Placeholder for real verification logic
    const { purchaseToken, productId, orderId } = await c.req.json();
    
    try {
        await c.env.DB.prepare(`
            INSERT INTO user_subscriptions (id, user_id, status, provider, expiry_date, purchase_token, order_id, product_id, updated_at)
            VALUES (?, ?, 'active', 'manual', DATE(CURRENT_TIMESTAMP, '+1 year'), ?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(user_id) DO UPDATE SET
                status = 'active',
                expiry_date = DATE(CURRENT_TIMESTAMP, '+1 year'),
                purchase_token = excluded.purchase_token,
                order_id = excluded.order_id,
                product_id = excluded.product_id,
                updated_at = CURRENT_TIMESTAMP
        `).bind(generateId(15), user.id, purchaseToken || null, orderId || null, productId || null).run();

        return c.json({ success: true });
    } catch (e: any) {
        return c.json({ error: e.message }, 500);
    }
});

export default router;