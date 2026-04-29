import type { Bindings } from '../types';

const GOOGLE_PLAY_SCOPE = 'https://www.googleapis.com/auth/androidpublisher';
const GOOGLE_OAUTH_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const GOOGLE_PLAY_PACKAGE_NAME_FALLBACK = 'com.nanomarkup.aliolo';
const SIGNATURE_HEADER = 'X-Aliolo-Signature';
const TIMESTAMP_HEADER = 'X-Aliolo-Timestamp';
const MAX_SIGNATURE_AGE_MS = 5 * 60 * 1000;

type GoogleServiceAccount = {
  client_email: string;
  private_key: string;
  private_key_id?: string;
  token_uri?: string;
};

type GoogleSubscriptionPurchaseV2 = {
  startTime?: string;
  subscriptionState?: string;
  latestOrderId?: string;
  acknowledgementState?: string;
  testPurchase?: unknown;
  linkedPurchaseToken?: string | null;
  externalAccountIdentifiers?: {
    externalAccountId?: string;
    obfuscatedExternalAccountId?: string;
  };
  lineItems?: Array<{
    productId?: string;
    expiryTime?: string;
    latestSuccessfulOrderId?: string;
    autoRenewingPlan?: {
      autoRenewEnabled?: boolean;
    };
  }>;
};

export type GooglePlayVerificationSource = 'client_verify' | 'rtdn' | 'reconcile';

export type GooglePlaySubscriptionVerification = {
  packageName: string;
  purchaseToken: string;
  productId: string | null;
  status: 'active' | 'inactive';
  subscriptionState: string | null;
  periodStart: string | null;
  periodEnd: string | null;
  willRenew: boolean | null;
  environment: 'test' | 'production';
  externalSubscriptionId: string;
  externalCustomerId: string | null;
  externalTransactionId: string | null;
  rawPayload: GoogleSubscriptionPurchaseV2;
};

export type GooglePlayWebhookPayload = {
  eventId: string;
  eventType: string;
  source: GooglePlayVerificationSource;
  verification: GooglePlaySubscriptionVerification;
  rawEvent?: unknown;
  userId?: string | null;
  purchaseToken?: string | null;
  productId?: string | null;
  packageName?: string | null;
  googleObfuscatedAccountId?: string | null;
  externalNotificationId?: string | null;
};

export type SharedRequestHeaders = {
  [SIGNATURE_HEADER]: string;
  [TIMESTAMP_HEADER]: string;
};

export class GooglePlayVerificationError extends Error {
  status: number;

  constructor(message: string, status = 500) {
    super(message);
    this.status = status;
  }
}

function decodeBase64(base64Value: string): Uint8Array {
  const normalized = base64Value.replace(/-/g, '+').replace(/_/g, '/');
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '=');
  const binary = atob(padded);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

function base64UrlEncode(value: string | Uint8Array | ArrayBuffer): string {
  const bytes =
    typeof value === 'string'
      ? new TextEncoder().encode(value)
      : value instanceof Uint8Array
        ? value
        : new Uint8Array(value);
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function pemToPkcs8(privateKeyPem: string): ArrayBuffer {
  const stripped = privateKeyPem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s+/g, '');
  return decodeBase64(stripped).buffer;
}

function parseServiceAccount(env: Bindings): GoogleServiceAccount {
  if (!env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON) {
    throw new GooglePlayVerificationError('Google Play verification is not configured', 503);
  }

  let parsed: GoogleServiceAccount;
  try {
    parsed = JSON.parse(env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON) as GoogleServiceAccount;
  } catch {
    throw new GooglePlayVerificationError('Google Play service account JSON is invalid', 500);
  }

  if (!parsed.client_email || !parsed.private_key) {
    throw new GooglePlayVerificationError('Google Play service account JSON is incomplete', 500);
  }

  return parsed;
}

function getPackageName(args: { packageName?: string | null }, env: Bindings) {
  return args.packageName || env.GOOGLE_PLAY_PACKAGE_NAME || GOOGLE_PLAY_PACKAGE_NAME_FALLBACK;
}

function shouldUseBroker(env: Bindings): boolean {
  if (env.GOOGLE_PLAY_VERIFICATION_MODE === 'broker') return true;
  if (env.GOOGLE_PLAY_VERIFICATION_MODE === 'direct') return false;
  return Boolean(env.GOOGLE_PLAY_VERIFIER_URL);
}

async function createAccessToken(serviceAccount: GoogleServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = {
    alg: 'RS256',
    typ: 'JWT',
    ...(serviceAccount.private_key_id ? { kid: serviceAccount.private_key_id } : {}),
  };
  const claims = {
    iss: serviceAccount.client_email,
    scope: GOOGLE_PLAY_SCOPE,
    aud: serviceAccount.token_uri ?? GOOGLE_OAUTH_TOKEN_URL,
    exp: now + 3600,
    iat: now,
  };

  const unsignedJwt = `${base64UrlEncode(JSON.stringify(header))}.${base64UrlEncode(JSON.stringify(claims))}`;
  const signingKey = await crypto.subtle.importKey(
    'pkcs8',
    pemToPkcs8(serviceAccount.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    signingKey,
    new TextEncoder().encode(unsignedJwt),
  );
  const assertion = `${unsignedJwt}.${base64UrlEncode(signature)}`;

  const tokenResponse = await fetch(serviceAccount.token_uri ?? GOOGLE_OAUTH_TOKEN_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });

  const tokenJson = await tokenResponse.json().catch(() => null) as
    | { access_token?: string; error?: string; error_description?: string }
    | null;
  if (!tokenResponse.ok || !tokenJson?.access_token) {
    throw new GooglePlayVerificationError(
      tokenJson?.error_description ?? tokenJson?.error ?? 'Could not obtain Google Play access token',
      tokenResponse.status || 502,
    );
  }

  return tokenJson.access_token;
}

function statusFromGoogleState(
  subscriptionState: string | null | undefined,
  periodEnd: string | null,
): 'active' | 'inactive' {
  if (subscriptionState === 'SUBSCRIPTION_STATE_ACTIVE') return 'active';
  if (subscriptionState === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD') return 'active';
  if (periodEnd && new Date(periodEnd).getTime() > Date.now()) {
    return subscriptionState === 'SUBSCRIPTION_STATE_ON_HOLD' ? 'inactive' : 'active';
  }
  return 'inactive';
}

export async function createSharedSignature(secret: string, timestamp: string, rawBody: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const digest = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(`${timestamp}.${rawBody}`),
  );
  return [...new Uint8Array(digest)]
    .map((value) => value.toString(16).padStart(2, '0'))
    .join('');
}

export async function createSignedHeaders(secret: string, rawBody: string): Promise<SharedRequestHeaders> {
  const timestamp = Date.now().toString();
  return {
    [SIGNATURE_HEADER]: await createSharedSignature(secret, timestamp, rawBody),
    [TIMESTAMP_HEADER]: timestamp,
  };
}

export async function validateSignedRequest(
  secret: string | undefined,
  rawBody: string,
  signature: string | null,
  timestamp: string | null,
): Promise<boolean> {
  if (!secret || !signature || !timestamp) return false;

  const timestampValue = Number(timestamp);
  if (!Number.isFinite(timestampValue)) return false;
  if (Math.abs(Date.now() - timestampValue) > MAX_SIGNATURE_AGE_MS) return false;

  const expected = await createSharedSignature(secret, timestamp, rawBody);
  return expected === signature;
}

async function verifyGooglePlaySubscriptionDirect(
  env: Bindings,
  args: {
    purchaseToken: string;
    productId?: string | null;
    packageName?: string | null;
  },
): Promise<GooglePlaySubscriptionVerification> {
  const serviceAccount = parseServiceAccount(env);
  const accessToken = await createAccessToken(serviceAccount);
  const packageName = getPackageName(args, env);
  const response = await fetch(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(packageName)}/purchases/subscriptionsv2/tokens/${encodeURIComponent(args.purchaseToken)}`,
    {
      headers: {
        Authorization: `Bearer ${accessToken}`,
        Accept: 'application/json',
      },
    },
  );

  const data = await response.json().catch(() => null) as GoogleSubscriptionPurchaseV2 | { error?: { message?: string } } | null;
  if (!response.ok || !data || 'error' in data) {
    throw new GooglePlayVerificationError(
      (data as { error?: { message?: string } } | null)?.error?.message ?? 'Google Play verification failed',
      response.status || 502,
    );
  }

  const lineItem =
    data.lineItems?.find((item) => item.productId === args.productId) ??
    data.lineItems?.[0];
  const verifiedProductId = lineItem?.productId ?? args.productId ?? null;
  if (args.productId && verifiedProductId && verifiedProductId !== args.productId) {
    throw new GooglePlayVerificationError('Google Play purchase does not match the requested product', 409);
  }

  const periodEnd = lineItem?.expiryTime ?? null;
  const status = statusFromGoogleState(data.subscriptionState, periodEnd);

  return {
    packageName,
    purchaseToken: args.purchaseToken,
    productId: verifiedProductId,
    status,
    subscriptionState: data.subscriptionState ?? null,
    periodStart: data.startTime ?? null,
    periodEnd,
    willRenew: lineItem?.autoRenewingPlan?.autoRenewEnabled ?? null,
    environment: data.testPurchase ? 'test' : 'production',
    externalSubscriptionId: args.purchaseToken,
    externalCustomerId:
      data.externalAccountIdentifiers?.obfuscatedExternalAccountId ??
      data.externalAccountIdentifiers?.externalAccountId ??
      null,
    externalTransactionId:
      lineItem?.latestSuccessfulOrderId ?? data.latestOrderId ?? null,
    rawPayload: data,
  };
}

async function verifyGooglePlaySubscriptionViaBroker(
  env: Bindings,
  args: {
    purchaseToken: string;
    productId?: string | null;
    packageName?: string | null;
    source?: GooglePlayVerificationSource;
    googleObfuscatedAccountId?: string | null;
  },
): Promise<GooglePlaySubscriptionVerification> {
  if (!env.GOOGLE_PLAY_VERIFIER_URL) {
    throw new GooglePlayVerificationError('Google Play verifier URL is not configured', 503);
  }
  if (!env.GOOGLE_PLAY_VERIFIER_SHARED_SECRET) {
    throw new GooglePlayVerificationError('Google Play verifier secret is not configured', 503);
  }

  const requestBody = JSON.stringify({
    purchaseToken: args.purchaseToken,
    productId: args.productId ?? null,
    packageName: getPackageName(args, env),
    source: args.source ?? 'client_verify',
    googleObfuscatedAccountId: args.googleObfuscatedAccountId ?? null,
  });
  const headers = await createSignedHeaders(env.GOOGLE_PLAY_VERIFIER_SHARED_SECRET, requestBody);
  const response = await fetch(`${env.GOOGLE_PLAY_VERIFIER_URL}/google-play/verify`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...headers,
    },
    body: requestBody,
  });

  const responseJson = await response.json().catch(() => null) as
    | GooglePlaySubscriptionVerification
    | { error?: string }
    | null;
  if (!response.ok || !responseJson || 'error' in responseJson) {
    throw new GooglePlayVerificationError(
      (responseJson as { error?: string } | null)?.error ?? 'Google Play verifier request failed',
      response.status || 502,
    );
  }

  return responseJson;
}

export async function verifyGooglePlaySubscription(
  env: Bindings,
  args: {
    purchaseToken: string;
    productId?: string | null;
    packageName?: string | null;
    source?: GooglePlayVerificationSource;
    googleObfuscatedAccountId?: string | null;
  },
): Promise<GooglePlaySubscriptionVerification> {
  if (shouldUseBroker(env)) {
    return verifyGooglePlaySubscriptionViaBroker(env, args);
  }

  return verifyGooglePlaySubscriptionDirect(env, args);
}

export function getSharedRequestHeaders() {
  return {
    signature: SIGNATURE_HEADER,
    timestamp: TIMESTAMP_HEADER,
  };
}
