import { OpenAPIHono, createRoute, z } from '@hono/zod-openapi';
import { generateId } from 'lucia';
import { initializeLucia, hashPassword } from '../auth';
import type { AppEnv } from '../types';
import { sendEmail } from '../utils/email';
import { getVerificationEmail, getResetPasswordEmail, getPasswordChangedEmail, getEmailChangeVerificationEmail, getEmailChangedNotificationEmail, getUserInvitationEmail, getWelcomeEmail, getAccountDeletedEmail } from '../utils/templates';
import { 
  SignupRequestSchema, 
  SignupInviteRequestSchema,
  LoginRequestSchema, 
  AuthResponseSchema, 
  MeResponseSchema, 
  UpdateProfileSchema,
  SuccessResponseSchema,
  ErrorResponseSchema,
  RequestOtpSchema,
  VerifyOtpSchema,
  ResetPasswordSchema,
  DeleteAccountSchema,
  UpdatePasswordSchema,
  RequestEmailChangeSchema,
  VerifyEmailChangeSchema,
  InviteUserSchema
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
    400: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Bad Request' },
    409: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Conflict' }
  }
});

router.openapi(signupRoute, async (c) => {
    let { email, password, username } = c.req.valid('json');

    const cleanEmail = email.toLowerCase().trim();
    password = password.trim();
    const passwordHash = await hashPassword(password);

    try {
        // Regular OTP flow
        const verification: any = await c.env.DB.prepare(
            "SELECT is_verified FROM email_verification_codes WHERE email = ?"
        ).bind(cleanEmail).first();

        if (!verification || verification.is_verified !== 1) {
            return c.json({ error: 'Email not verified' } as any, 400);
        }

        const existingUser: any = await c.env.DB.prepare(
            "SELECT id, password_hash FROM profiles WHERE email = ?"
        ).bind(cleanEmail).first();

        let userId: string;

        if (existingUser) {
            if (existingUser.password_hash) {
                return c.json({ error: 'User already exists' } as any, 409);
            }
            userId = existingUser.id;
            await c.env.DB.prepare(
                "UPDATE profiles SET password_hash = ?, username = COALESCE(username, ?), updated_at = CURRENT_TIMESTAMP WHERE id = ?"
            ).bind(passwordHash, username || cleanEmail.split('@')[0], userId).run();
        } else {
            userId = generateId(15);
            await c.env.DB.prepare(
                "INSERT INTO profiles (id, email, username, password_hash, main_pillar_id) VALUES (?, ?, ?, ?, 6)"
            ).bind(userId, cleanEmail, username || cleanEmail.split('@')[0], passwordHash).run();
        }

        // Cleanup
        await c.env.DB.prepare("DELETE FROM email_verification_codes WHERE email = ?").bind(cleanEmail).run();

        // Send Welcome Email
        try {
            const welcomeUsername = username || cleanEmail.split('@')[0];
            await sendEmail(
                cleanEmail,
                'Welcome to Aliolo!',
                `Welcome to Aliolo, ${welcomeUsername}! Your account is now active.`,
                c.env,
                getWelcomeEmail(welcomeUsername)
            );
        } catch (emailErr) {
            console.error('Failed to send welcome email:', emailErr);
        }

        const lucia = initializeLucia(c.env.DB);
        const session = await lucia.createSession(userId, {});
        c.header("Set-Cookie", lucia.createSessionCookie(session.id).serialize(), { append: true });
        
        return c.json({ user: { id: userId, email: cleanEmail, username }, session_id: session.id }, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 400);
    }
});

const signupInviteRoute = createRoute({
  method: 'post',
  path: '/signup-invite',
  summary: 'Sign up with invitation token',
  request: {
    body: {
      content: { 'application/json': { schema: SignupInviteRequestSchema } }
    }
  },
  responses: {
    200: { content: { 'application/json': { schema: AuthResponseSchema } }, description: 'Success' },
    400: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Bad Request' },
    409: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Conflict' }
  }
});

router.openapi(signupInviteRoute, async (c) => {
    let { email, password, username, invite_token } = c.req.valid('json');

    const cleanEmail = email.toLowerCase().trim();
    password = password.trim();
    const passwordHash = await hashPassword(password);

    try {
        // Verify invite token
        const invite: any = await c.env.DB.prepare(
            "SELECT email, inviter_id, expires_at FROM invitations WHERE token = ?"
        ).bind(invite_token).first();

        const now = Math.floor(Date.now() / 1000);
        if (!invite) {
            console.log(`Signup Error: Invitation token not found: ${invite_token}`);
            return c.json({ error: 'Invalid or expired invitation' } as any, 400);
        }
        if (invite.expires_at < now) {
            console.log(`Signup Error: Invitation token expired for ${invite.email}`);
            return c.json({ error: 'Invalid or expired invitation' } as any, 400);
        }
        if (invite.email.toLowerCase().trim() !== cleanEmail) {
            console.log(`Signup Error: Email mismatch. Invite: ${invite.email.toLowerCase().trim()}, Signup: ${cleanEmail}`);
            return c.json({ error: 'Invalid or expired invitation' } as any, 400);
        }
        const inviterId = invite.inviter_id;

        const existingUser: any = await c.env.DB.prepare(
            "SELECT id, password_hash FROM profiles WHERE email = ?"
        ).bind(cleanEmail).first();

        let userId: string;

        if (existingUser) {
            if (existingUser.password_hash) {
                return c.json({ error: 'User already exists' } as any, 409);
            }
            userId = existingUser.id;
            await c.env.DB.prepare(
                "UPDATE profiles SET password_hash = ?, username = COALESCE(username, ?), updated_at = CURRENT_TIMESTAMP WHERE id = ?"
            ).bind(passwordHash, username || cleanEmail.split('@')[0], userId).run();
        } else {
            userId = generateId(15);
            await c.env.DB.prepare(
                "INSERT INTO profiles (id, email, username, password_hash, main_pillar_id) VALUES (?, ?, ?, ?, 6)"
            ).bind(userId, cleanEmail, username || cleanEmail.split('@')[0], passwordHash).run();
        }

        // Cleanup
        await c.env.DB.prepare("DELETE FROM invitations WHERE token = ?").bind(invite_token).run();
        // Auto-accept friendship if invited by someone
        if (inviterId && inviterId !== 'system') {
            await c.env.DB.prepare(
                "INSERT INTO user_friendships (sender_id, receiver_id, status) VALUES (?, ?, 'accepted') ON CONFLICT DO NOTHING"
            ).bind(inviterId, userId).run();
        }

        // Send Welcome Email
        try {
            const welcomeUsername = username || cleanEmail.split('@')[0];
            await sendEmail(
                cleanEmail,
                'Welcome to Aliolo!',
                `Welcome to Aliolo, ${welcomeUsername}! Your account is now active.`,
                c.env,
                getWelcomeEmail(welcomeUsername)
            );
        } catch (emailErr) {
            console.error('Failed to send welcome email:', emailErr);
        }

        const lucia = initializeLucia(c.env.DB);
        const session = await lucia.createSession(userId, {});
        c.header("Set-Cookie", lucia.createSessionCookie(session.id).serialize(), { append: true });
        
        return c.json({ user: { id: userId, email: cleanEmail, username }, session_id: session.id }, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 400);
    }
});

const requestOtpRoute = createRoute({
  method: 'post',
  path: '/request-otp',
  summary: 'Request email verification OTP',
  request: {
    body: {
      content: { 'application/json': { schema: RequestOtpSchema } }
    }
  },
  responses: {
    200: { content: { 'application/json': { schema: SuccessResponseSchema } }, description: 'Success' },
    400: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Bad Request' },
    409: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Conflict' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(requestOtpRoute, async (c) => {
    const { email } = c.req.valid('json');
    const cleanEmail = email.toLowerCase().trim();
    
    try {
        // Check if user already exists
        const existingUser = await c.env.DB.prepare(
            "SELECT id FROM profiles WHERE email = ? AND password_hash IS NOT NULL"
        ).bind(cleanEmail).first();

        if (existingUser) {
            return c.json({ error: 'User with this email already exists' } as any, 409);
        }

        // Generate 6-digit OTP
        const code = Math.floor(100000 + Math.random() * 900000).toString();
        const expiresAt = Math.floor(Date.now() / 1000) + 15 * 60; // 15 minutes

        await c.env.DB.prepare(
            "INSERT INTO email_verification_codes (email, code, expires_at, is_verified) VALUES (?, ?, ?, 0) ON CONFLICT(email) DO UPDATE SET code = excluded.code, expires_at = excluded.expires_at, is_verified = 0"
        ).bind(cleanEmail, code, expiresAt).run();

        await sendEmail(
            cleanEmail,
            'Verification Code - Aliolo',
            `Your verification code is: ${code}`,
            c.env,
            getVerificationEmail(code)
        );

        return c.json({ success: true }, 200);
    } catch (e: any) {
        console.error('Request OTP Error:', e);
        return c.json({ error: e.message } as any, 500);
    }
});

const verifyOtpRoute = createRoute({
  method: 'post',
  path: '/verify-otp',
  summary: 'Verify email OTP',
  request: {
    body: {
      content: { 'application/json': { schema: VerifyOtpSchema } }
    }
  },
  responses: {
    200: { content: { 'application/json': { schema: SuccessResponseSchema } }, description: 'Success' },
    400: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Invalid or expired code' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(verifyOtpRoute, async (c) => {
    const { email, code } = c.req.valid('json');
    const cleanEmail = email.toLowerCase().trim();
    const now = Math.floor(Date.now() / 1000);

    try {
        const record: any = await c.env.DB.prepare(
            "SELECT * FROM email_verification_codes WHERE email = ? AND code = ?"
        ).bind(cleanEmail, code).first();

        if (!record || record.expires_at < now) {
            return c.json({ error: 'Invalid or expired verification code' } as any, 400);
        }

        await c.env.DB.prepare(
            "UPDATE email_verification_codes SET is_verified = 1 WHERE email = ?"
        ).bind(cleanEmail).run();

        return c.json({ success: true }, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
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
    let { email, password } = c.req.valid('json');
    password = password.trim();

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
    console.log('UpdateProfile payload received:', JSON.stringify(updateData));
    
    // Remote protected fields
    delete updateData.id;
    delete updateData.email;
    delete updateData.created_at;
    delete updateData.password_hash;

    // Convert booleans to numbers for SQLite
    for (const key in updateData) {
        if (typeof updateData[key] === 'boolean') {
            updateData[key] = updateData[key] ? 1 : 0;
        }
    }

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

const updatePasswordRoute = createRoute({
  method: 'post',
  path: '/update-password',
  summary: 'Update password for logged in user',
  request: {
    body: {
      content: { 'application/json': { schema: UpdatePasswordSchema } }
    }
  },
  responses: {
    200: { content: { 'application/json': { schema: SuccessResponseSchema } }, description: 'Success' },
    401: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Unauthorized' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(updatePasswordRoute, async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' } as any, 401);

    const { new_password } = c.req.valid('json');
    const passwordHash = await hashPassword(new_password.trim());

    try {
        await c.env.DB.prepare(
            "UPDATE profiles SET password_hash = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?"
        ).bind(passwordHash, user.id).run();

        const fullUser: any = await c.env.DB.prepare("SELECT email FROM profiles WHERE id = ?").bind(user.id).first();

        // Send confirmation email
        if (fullUser?.email) {
            try {
                await sendEmail(
                    fullUser.email,
                    'Security Alert: Your aliolo password has been changed',
                    'Your password was recently updated.',
                    c.env,
                    getPasswordChangedEmail(fullUser.email)
                );
            } catch (emailErr) {
                console.error('Failed to send password change alert:', emailErr);
            }
        }

        return c.json({ success: true }, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

const resetPasswordRoute = createRoute({
  method: 'post',
  path: '/reset-password',
  summary: 'Reset password using OTP',
  request: {
    body: {
      content: { 'application/json': { schema: ResetPasswordSchema } }
    }
  },
  responses: {
    200: { content: { 'application/json': { schema: SuccessResponseSchema } }, description: 'Success' },
    400: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Invalid or expired code' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(resetPasswordRoute, async (c) => {
    let { email, code, password } = c.req.valid('json');
    const cleanEmail = email.toLowerCase().trim();
    password = password.trim();
    const now = Math.floor(Date.now() / 1000);

    try {
        const record: any = await c.env.DB.prepare(
            "SELECT * FROM email_verification_codes WHERE email = ? AND code = ?"
        ).bind(cleanEmail, code).first();

        if (!record || record.expires_at < now) {
            return c.json({ error: 'Invalid or expired verification code' } as any, 400);
        }

        const passwordHash = await hashPassword(password);
        
        await c.env.DB.prepare(
            "UPDATE profiles SET password_hash = ?, updated_at = CURRENT_TIMESTAMP WHERE email = ?"
        ).bind(passwordHash, cleanEmail).run();

        // Clean up
        await c.env.DB.prepare("DELETE FROM email_verification_codes WHERE email = ?").bind(cleanEmail).run();

        // Send confirmation email
        await sendEmail(
            cleanEmail,
            'Security Alert: Your aliolo password has been changed',
            'Your password was recently updated.',
            c.env,
            getPasswordChangedEmail(cleanEmail)
        );

        return c.json({ success: true }, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

const requestPasswordResetRoute = createRoute({
  method: 'post',
  path: '/request-password-reset',
  summary: 'Request password reset OTP',
  request: {
    body: {
      content: { 'application/json': { schema: RequestOtpSchema } }
    }
  },
  responses: {
    200: { content: { 'application/json': { schema: SuccessResponseSchema } }, description: 'Success' },
    404: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'User not found' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(requestPasswordResetRoute, async (c) => {
    const { email } = c.req.valid('json');
    const cleanEmail = email.toLowerCase().trim();

    try {
        const user = await c.env.DB.prepare("SELECT id FROM profiles WHERE email = ?").bind(cleanEmail).first();
        if (!user) {
            return c.json({ error: 'User with this email does not exist' } as any, 404);
        }

        const code = Math.floor(100000 + Math.random() * 900000).toString();
        const expiresAt = Math.floor(Date.now() / 1000) + 15 * 60; // 15 minutes

        await c.env.DB.prepare(
            "INSERT INTO email_verification_codes (email, code, expires_at, is_verified) VALUES (?, ?, ?, 0) ON CONFLICT(email) DO UPDATE SET code = excluded.code, expires_at = excluded.expires_at, is_verified = 0"
        ).bind(cleanEmail, code, expiresAt).run();

        await sendEmail(
            cleanEmail,
            'Password Reset - Aliolo',
            `Your password reset code is: ${code}`,
            c.env,
            getResetPasswordEmail(code)
        );

        return c.json({ success: true }, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

const deleteAccountRoute = createRoute({
  method: 'post',
  path: '/delete',
  summary: 'Delete user account',
  request: {
    body: {
      content: { 'application/json': { schema: DeleteAccountSchema } }
    }
  },
  responses: {
    200: { content: { 'application/json': { schema: SuccessResponseSchema } }, description: 'Success' },
    401: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Unauthorized' },
    400: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Invalid password' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(deleteAccountRoute, async (c) => {
    const user = c.get("user");
    const session = c.get("session");
    if (!user || !session) return c.json({ error: 'Unauthorized' } as any, 401);

    let { password } = c.req.valid('json');
    password = password.trim();

    try {
        const fullUser: any = await c.env.DB.prepare(
            "SELECT id, email, username, password_hash FROM profiles WHERE id = ?"
        ).bind(user.id).first();

        if (!fullUser || !fullUser.password_hash) {
            return c.json({ error: 'User not found' } as any, 400);
        }

        const hashedInput = await hashPassword(password);
        
        if (hashedInput !== fullUser.password_hash) {
            console.log(`Delete Account: Password mismatch for ${fullUser.email}`);
            return c.json({ error: 'Invalid password' } as any, 400);
        }

        const userId = user.id;

        // Cleanup user data
        // Many of these should have ON DELETE CASCADE, but we execute manually for safety
        await c.env.DB.batch([
            c.env.DB.prepare("DELETE FROM progress WHERE user_id = ?").bind(userId),
            c.env.DB.prepare("DELETE FROM user_subjects WHERE user_id = ?").bind(userId),
            c.env.DB.prepare("DELETE FROM user_subscriptions WHERE user_id = ?").bind(userId),
            c.env.DB.prepare("DELETE FROM user_friendships WHERE sender_id = ? OR receiver_id = ?").bind(userId, userId),
            c.env.DB.prepare("DELETE FROM feedback_replies WHERE user_id = ?").bind(userId),
            c.env.DB.prepare("DELETE FROM feedbacks WHERE user_id = ?").bind(userId),
            c.env.DB.prepare("DELETE FROM cards WHERE owner_id = ?").bind(userId),
            c.env.DB.prepare("DELETE FROM subjects WHERE owner_id = ?").bind(userId),
            c.env.DB.prepare("DELETE FROM collections WHERE owner_id = ?").bind(userId),
            c.env.DB.prepare("DELETE FROM folders WHERE owner_id = ?").bind(userId),
            c.env.DB.prepare("DELETE FROM sessions WHERE user_id = ?").bind(userId),
            c.env.DB.prepare("DELETE FROM profiles WHERE id = ?").bind(userId),
        ]);

        const lucia = initializeLucia(c.env.DB);
        c.header("Set-Cookie", lucia.createBlankSessionCookie().serialize(), { append: true });

        // Send confirmation email
        try {
            const deletedUsername = fullUser.username || fullUser.email.split('@')[0];
            await sendEmail(
                fullUser.email,
                'Account Deleted - Aliolo',
                `Hello ${deletedUsername}, your Aliolo account has been successfully deleted.`,
                c.env,
                getAccountDeletedEmail(deletedUsername)
            );
        } catch (emailErr) {
            console.error('Failed to send account deletion email:', emailErr);
        }

        return c.json({ success: true }, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

const requestEmailChangeRoute = createRoute({
  method: 'post',
  path: '/request-email-change',
  summary: 'Request email address change',
  request: {
    body: {
      content: { 'application/json': { schema: RequestEmailChangeSchema } }
    }
  },
  responses: {
    200: { content: { 'application/json': { schema: SuccessResponseSchema } }, description: 'Success' },
    401: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Unauthorized' },
    409: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Conflict' },
    400: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Invalid password' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(requestEmailChangeRoute, async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' } as any, 401);

    let { new_email, password } = c.req.valid('json');
    const cleanNewEmail = new_email.toLowerCase().trim();
    password = password.trim();

    try {
        const fullUser: any = await c.env.DB.prepare(
            "SELECT email, password_hash FROM profiles WHERE id = ?"
        ).bind(user.id).first();

        const hashedInput = await hashPassword(password);
        if (hashedInput !== fullUser.password_hash) {
            return c.json({ error: 'Invalid password' } as any, 400);
        }

        const existing = await c.env.DB.prepare("SELECT id FROM profiles WHERE email = ?").bind(cleanNewEmail).first();
        if (existing) {
            return c.json({ error: 'Email already in use' } as any, 409);
        }

        const code = Math.floor(100000 + Math.random() * 900000).toString();
        const expiresAt = Math.floor(Date.now() / 1000) + 15 * 60;

        await c.env.DB.prepare(
            "INSERT INTO email_verification_codes (email, code, expires_at, is_verified) VALUES (?, ?, ?, 0) ON CONFLICT(email) DO UPDATE SET code = excluded.code, expires_at = excluded.expires_at, is_verified = 0"
        ).bind(cleanNewEmail, code, expiresAt).run();

        await sendEmail(
            cleanNewEmail,
            'Confirm your new email address for aliolo',
            `Your verification code is: ${code}`,
            c.env,
            getEmailChangeVerificationEmail(fullUser.email, cleanNewEmail, code)
        );

        return c.json({ success: true }, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

const verifyEmailChangeRoute = createRoute({
  method: 'post',
  path: '/verify-email-change',
  summary: 'Verify and complete email change',
  request: {
    body: {
      content: { 'application/json': { schema: VerifyEmailChangeSchema } }
    }
  },
  responses: {
    200: { content: { 'application/json': { schema: SuccessResponseSchema } }, description: 'Success' },
    401: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Unauthorized' },
    400: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Invalid or expired code' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(verifyEmailChangeRoute, async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' } as any, 401);

    const { new_email, code } = c.req.valid('json');
    const cleanNewEmail = new_email.toLowerCase().trim();
    const now = Math.floor(Date.now() / 1000);

    try {
        const record: any = await c.env.DB.prepare(
            "SELECT * FROM email_verification_codes WHERE email = ? AND code = ?"
        ).bind(cleanNewEmail, code).first();

        if (!record || record.expires_at < now) {
            return c.json({ error: 'Invalid or expired verification code' } as any, 400);
        }

        const oldUser: any = await c.env.DB.prepare("SELECT email FROM profiles WHERE id = ?").bind(user.id).first();
        const oldEmail = oldUser.email;

        await c.env.DB.batch([
            c.env.DB.prepare("UPDATE profiles SET email = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?").bind(cleanNewEmail, user.id),
            c.env.DB.prepare("DELETE FROM email_verification_codes WHERE email = ?").bind(cleanNewEmail)
        ]);

        await sendEmail(
            oldEmail,
            'Security Alert: Your aliolo email address has been changed',
            'Your email address was recently updated.',
            c.env,
            getEmailChangedNotificationEmail(oldEmail, cleanNewEmail)
        );

        return c.json({ success: true }, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

const inviteUserRoute = createRoute({
  method: 'post',
  path: '/invite',
  summary: 'Invite user by email',
  request: {
    body: {
      content: { 'application/json': { schema: InviteUserSchema } }
    }
  },
  responses: {
    200: { content: { 'application/json': { schema: SuccessResponseSchema } }, description: 'Success' },
    400: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Bad Request' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(inviteUserRoute, async (c) => {
    const user = c.get("user");
    const { email } = c.req.valid('json');
    const cleanEmail = email.toLowerCase().trim();

    try {
        const existing: any = await c.env.DB.prepare("SELECT id FROM profiles WHERE email = ?").bind(cleanEmail).first();
        if (existing) {
            if (user) {
                await c.env.DB.prepare(
                    "INSERT INTO user_friendships (sender_id, receiver_id, status) VALUES (?, ?, 'pending') ON CONFLICT DO NOTHING"
                ).bind(user.id, existing.id).run();
            }
            return c.json({ success: true, message: 'User already registered, friend request sent' }, 200);
        }

        // Generate secure 32-char token
        const token = generateId(32);
        const expiresAt = Math.floor(Date.now() / 1000) + 7 * 24 * 60 * 60; // 7 days

        await c.env.DB.prepare(
            "INSERT INTO invitations (token, email, inviter_id, expires_at) VALUES (?, ?, ?, ?)"
        ).bind(token, cleanEmail, user?.id || 'system', expiresAt).run();

        const inviteUrl = `https://aliolo.com/?invite=${token}`;

        await sendEmail(
            cleanEmail,
            "You're invited to join aliolo",
            `Hello! You've been invited to join aliolo. Accept your invitation here: ${inviteUrl}`,
            c.env,
            getUserInvitationEmail(inviteUrl)
        );

        return c.json({ success: true }, 200);
    } catch (e: any) {
        return c.json({ error: e.message } as any, 500);
    }
});

const verifyInviteRoute = createRoute({
  method: 'get',
  path: '/verify-invite',
  summary: 'Verify an invitation token',
  request: {
    query: z.object({ token: z.string() })
  },
  responses: {
    200: { content: { 'application/json': { schema: z.object({ email: z.string(), token: z.string() }) } }, description: 'Success' },
    404: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Invalid or expired' },
    500: { content: { 'application/json': { schema: ErrorResponseSchema } }, description: 'Error' }
  }
});

router.openapi(verifyInviteRoute, async (c) => {
    const token = c.req.query('token');
    const now = Math.floor(Date.now() / 1000);

    try {
        const invite: any = await c.env.DB.prepare(
            "SELECT email, expires_at FROM invitations WHERE token = ?"
        ).bind(token).first();

        if (!invite || invite.expires_at < now) {
            return c.json({ error: 'Invalid or expired invitation' } as any, 404);
        }

        return c.json({ email: invite.email, token: token }, 200);
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
