import { OpenAPIHono } from '@hono/zod-openapi';
import type { AppEnv } from '../types';

const router = new OpenAPIHono<AppEnv>();

router.get('/', async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    try {
        const { results: friendships } = await c.env.DB.prepare(`
            SELECT f.*, 
            s.username as sender_username, s.avatar_url as sender_avatar,
            r.username as receiver_username, r.avatar_url as receiver_avatar
            FROM user_friendships f
            JOIN profiles s ON f.sender_id = s.id
            JOIN profiles r ON f.receiver_id = r.id
            WHERE f.sender_id = ? OR f.receiver_id = ?
        `).bind(user.id, user.id).all();

        // Also fetch pending invitations sent by this user
        const { results: invitations } = await c.env.DB.prepare(`
            SELECT token as id, inviter_id as sender_id, email as receiver_username, 
            'invited' as status, datetime(expires_at, 'unixepoch') as created_at
            FROM invitations
            WHERE inviter_id = ?
        `).bind(user.id).all();

        // Transform invitations to match friendship format
        const invitationFriendships = invitations.map((inv: any) => ({
            ...inv,
            receiver_id: null,
            sender_username: user.username || 'Me',
            sender_avatar: null,
            receiver_avatar: null
        }));
        
        return c.json([...friendships, ...invitationFriendships]);
    } catch (e: any) {
        return c.json({ error: e.message }, 500);
    }
});

router.post('/request', async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const { email, target_id } = await c.req.json();
    let targetId = target_id;

    try {
        if (email) {
            const target: any = await c.env.DB.prepare("SELECT id FROM profiles WHERE email = ?").bind(email.toLowerCase()).first();
            if (!target) return c.json({ error: 'user_not_found' }, 404);
            targetId = target.id;
        }

        if (!targetId) return c.json({ error: 'Target user required' }, 400);
        if (targetId === user.id) return c.json({ error: 'Cannot add yourself' }, 400);

        const existing: any = await c.env.DB.prepare(`
            SELECT status FROM user_friendships 
            WHERE (sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)
        `).bind(user.id, targetId, targetId, user.id).first();

        if (existing) {
            return c.json({ error: existing.status === 'accepted' ? 'Already friends' : 'Request pending' }, 400);
        }

        await c.env.DB.prepare(
            "INSERT INTO user_friendships (sender_id, receiver_id, status) VALUES (?, ?, 'pending')"
        ).bind(user.id, targetId).run();

        return c.json({ success: true });
    } catch (e: any) {
        return c.json({ error: e.message }, 500);
    }
});

router.post('/accept/:id', async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' }, 401);
    const id = c.req.param('id');

    try {
        await c.env.DB.prepare(
            "UPDATE user_friendships SET status = 'accepted' WHERE id = ? AND receiver_id = ?"
        ).bind(id, user.id).run();
        return c.json({ success: true });
    } catch (e: any) {
        return c.json({ error: e.message }, 500);
    }
});

router.delete('/:id', async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' }, 401);
    const id = c.req.param('id');

    try {
        // Try deleting from friendships (id is integer)
        const result = await c.env.DB.prepare(
            "DELETE FROM user_friendships WHERE id = ? AND (sender_id = ? OR receiver_id = ?)"
        ).bind(id, user.id, user.id).run();

        if (result.meta.changes === 0) {
            // Try deleting from invitations (id is token string)
            await c.env.DB.prepare(
                "DELETE FROM invitations WHERE token = ? AND inviter_id = ?"
            ).bind(id, user.id).run();
        }
        
        return c.json({ success: true });
    } catch (e: any) {
        return c.json({ error: e.message }, 500);
    }
});

router.get('/leaderboard', async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    try {
        const { results } = await c.env.DB.prepare(`
            SELECT p.* FROM profiles p
            WHERE p.id = ? OR p.id IN (
                SELECT sender_id FROM user_friendships WHERE receiver_id = ? AND status = 'accepted'
                UNION
                SELECT receiver_id FROM user_friendships WHERE sender_id = ? AND status = 'accepted'
            )
            ORDER BY p.total_xp DESC
        `).bind(user.id, user.id, user.id).all();
        
        return c.json(results);
    } catch (e: any) {
        return c.json({ error: e.message }, 500);
    }
});

export default router;