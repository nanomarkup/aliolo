import { env } from 'cloudflare:test';
import app from '../src/index';

export async function signupUser(user: { email: string; password?: string; username?: string }) {
    const password = user.password || 'password123';
    const username = user.username || user.email.split('@')[0];

    // 1. Request OTP
    await app.request('/api/auth/request-otp', {
      method: 'POST',
      body: JSON.stringify({ email: user.email }),
      headers: { 'Content-Type': 'application/json' }
    }, env);

    // 2. Get OTP from DB
    const record: any = await env.DB.prepare(
        "SELECT code FROM email_verification_codes WHERE email = ?"
    ).bind(user.email.toLowerCase()).first();
    const code = record.code;

    // 3. Verify OTP
    await app.request('/api/auth/verify-otp', {
      method: 'POST',
      body: JSON.stringify({ email: user.email, code }),
      headers: { 'Content-Type': 'application/json' }
    }, env);

    // 4. Final Signup
    const res = await app.request('/api/auth/signup', {
      method: 'POST',
      body: JSON.stringify({ email: user.email, password, username }),
      headers: { 'Content-Type': 'application/json' }
    }, env);

    if (res.status !== 200) {
        throw new Error(`Signup failed: ${JSON.stringify(await res.json())}`);
    }

    return await res.json() as any;
}
