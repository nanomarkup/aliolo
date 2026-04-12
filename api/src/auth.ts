import { Lucia } from "lucia";
import { D1Adapter } from "@lucia-auth/adapter-sqlite";

export function initializeLucia(db: D1Database) {
	const adapter = new D1Adapter(db, {
		user: "profiles",
		session: "sessions"
	});

	return new Lucia(adapter, {
		sessionCookie: {
			attributes: {
				secure: true // set to `false` when developing locally if not using https
			}
		},
		getUserAttributes: (attributes) => {
			return {
				username: attributes.username,
				email: attributes.email
			};
		}
	});
}

declare module "lucia" {
	interface Register {
		Lucia: ReturnType<typeof initializeLucia>;
		DatabaseUserAttributes: DatabaseUserAttributes;
	}
}

interface DatabaseUserAttributes {
	username: string;
	email: string;
}

// Basic Hashing for demonstration (Replace with Scrypt/Argon2 later)
export async function hashPassword(password: string) {
    const encoder = new TextEncoder();
    const data = encoder.encode(password);
    const hash = await crypto.subtle.digest('SHA-256', data);
    return btoa(String.fromCharCode(...new Uint8Array(hash)));
}
