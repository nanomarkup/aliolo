import { OpenAPIHono, createRoute, z } from '@hono/zod-openapi';
import { generateId } from 'lucia';
import { initializeLucia, hashPassword } from '../auth';
import type { AppEnv } from '../types';
import { 
  SignupRequestSchema, 
  LoginRequestSchema, 
  AuthResponseSchema, 
  MeResponseSchema, 
  UpdateProfileSchema,
  SuccessResponseSchema,
  ErrorResponseSchema
} from '../schemas/auth';

const router = new OpenAPIHono<AppEnv>();

const signupRoute = createRoute({
  method: 'post',
  path: '/signup',
  summary: 'Sign up',
  request: {
    body: {
      content: { 'application/json': { schema: SignupRequestSchema } }
    }
  },
  responses: {
    200: { content: { 'application/json': { schema: AuthResponseSchema } }, description: 'Success' },
    400: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Bad Request' }
  }
});

router.openapi(signupRoute, async (c) => {
    const { email, password, username } = c.req.valid('json');

    const cleanEmail = email.toLowerCase().trim();
    const passwordHash = await hashPassword(password);

    try {
        const existingUser: any = await c.env.DB.prepare(
            "SELECT id, password_hash FROM profiles WHERE email = ?"
        ).bind(cleanEmail).first();

        let userId: string;

        if (existingUser) {
            if (existingUser.password_hash) {
                return c.json({ error: 'User already exists' } as any, 400);
            }
            userId = existingUser.id;
            await c.env.DB.prepare(
                "UPDATE profiles SET password_hash = ?, username = COALESCE(username, ?), updated_at = CURRENT_TIMESTAMP WHERE id = ?"
            ).bind(passwordHash, username || cleanEmail.split('@')[0], userId).run();
        } else {
            userId = generateId(15);
            await c.env.DB.prepare(
                "INSERT INTO profiles (id, email, username, password_hash) VALUES (?, ?, ?, ?)"
            ).bind(userId, cleanEmail, username || cleanEmail.split('@')[0], passwordHash).run();
        }

        const lucia = initializeLucia(c.env.DB);
        const session = await lucia.createSession(userId, {});
        c.header("Set-Cookie", lucia.createSessionCookie(session.id).serialize(), { append: true });
        
        return c.json({ user: { id: userId, email: cleanEmail, username }, session_id: session.id }, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 400);
    }
});

const loginRoute = createRoute({
  method: 'post',
  path: '/login',
  summary: 'Login',
  request: {
    body: {
      content: { 'application/json': { schema: LoginRequestSchema } }
    }
  },
  responses: {
    200: { content: { 'application/json': { schema: AuthResponseSchema } }, description: 'Success' },
    400: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Invalid credentials' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(loginRoute, async (c) => {
    const { email, password } = c.req.valid('json');

    try {
        const user: any = await c.env.DB.prepare(
            "SELECT * FROM profiles WHERE email = ?"
        ).bind(email).first();

        if (!user || !user.password_hash) {
            return c.json({ error: 'Invalid email or password' } as any, 400);
        }

        const validPassword = (await hashPassword(password)) === user.password_hash;
        if (!validPassword) {
            return c.json({ error: 'Invalid email or password' } as any, 400);
        }

        const lucia = initializeLucia(c.env.DB);
        const session = await lucia.createSession(user.id, {});
        c.header("Set-Cookie", lucia.createSessionCookie(session.id).serialize(), { append: true });
        
        return c.json({ user: { id: user.id, email: user.email, username: user.username }, session_id: session.id }, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

const meRoute = createRoute({
  method: 'get',
  path: '/me',
  summary: 'Get current user',
  responses: {
    200: { content: { 'application/json': { schema: MeResponseSchema } }, description: 'Success' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(meRoute, async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ user: null }, 200);
    
    try {
        const fullUser = await c.env.DB.prepare(
            "SELECT * FROM profiles WHERE id = ?"
        ).bind(user.id).first();
        return c.json({ user: fullUser as any }, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

const updateRoute = createRoute({
  method: 'post',
  path: '/update',
  summary: 'Update profile',
  request: {
    body: {
      content: { 'application/json': { schema: UpdateProfileSchema } }
    }
  },
  responses: {
    200: { content: { 'application/json': { schema: SuccessResponseSchema } }, description: 'Success' },
    401: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Unauthorized' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(updateRoute, async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' } as any, 401);

    const updateData = c.req.valid('json') as any;
    
    // Remote protected fields
    delete updateData.id;
    delete updateData.email;
    delete updateData.created_at;
    delete updateData.password_hash;

    const columns = Object.keys(updateData);
    if (columns.length === 0) return c.json({ success: true }, 200);

    const setClause = columns.map(col => `${col} = ?`).join(', ');
    const values = Object.values(updateData);

    try {
        await c.env.DB.prepare(
            `UPDATE profiles SET ${setClause}, updated_at = CURRENT_TIMESTAMP WHERE id = ?`
        ).bind(...values, user.id).run();
        return c.json({ success: true }, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

const logoutRoute = createRoute({
  method: 'post',
  path: '/logout',
  summary: 'Logout',
  responses: {
    200: { content: { 'application/json': { schema: z.object({ message: z.string() }) } }, description: 'Success' }
  }
});

router.openapi(logoutRoute, async (c) => {
    const session = c.get("session");
    if (!session) return c.json({ message: 'No session' }, 200);

    const lucia = initializeLucia(c.env.DB);
    await lucia.invalidateSession(session.id);
    c.header("Set-Cookie", lucia.createBlankSessionCookie().serialize(), { append: true });
    return c.json({ message: 'Logged out' }, 200);
});

export default router;
