import { createServer } from 'node:http';
import { createHmac } from 'node:crypto';
import { Readable } from 'node:stream';

type VerifyRequest = {
  purchaseToken: string;
  productId?: string | null;
  packageName?: string | null;
  source?: 'client_verify' | 'rtdn' | 'reconcile';
  googleObfuscatedAccountId?: string | null;
};

type Verification = {
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

type WorkerWebhookPayload = {
  eventId: string;
  eventType: string;
  source: 'rtdn' | 'reconcile';
  verification: Verification;
  rawEvent?: unknown;
  userId?: string | null;
  purchaseToken?: string | null;
  productId?: string | null;
  packageName?: string | null;
  googleObfuscatedAccountId?: string | null;
  externalNotificationId?: string | null;
};

type ReconcileCandidate = {
  userId?: string | null;
  purchaseToken: string;
  productId?: string | null;
  packageName?: string | null;
  googleObfuscatedAccountId?: string | null;
};

type GoogleSubscriptionPurchaseV2 = {
  startTime?: string;
  subscriptionState?: string;
  latestOrderId?: string;
  testPurchase?: unknown;
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

type GoogleApiErrorResponse = {
  error?: {
    message?: string;
  };
};

function isGoogleApiErrorResponse(
  value: GoogleSubscriptionPurchaseV2 | GoogleApiErrorResponse | null,
): value is GoogleApiErrorResponse {
  return Boolean(value && 'error' in value);
}

type PubSubPushBody = {
  message?: {
    data?: string;
    messageId?: string;
    publishTime?: string;
  };
  subscription?: string;
};

type RtdnPayload = {
  version?: string;
  packageName?: string;
  eventTimeMillis?: string;
  subscriptionNotification?: {
    version?: string;
    notificationType?: number;
    purchaseToken?: string;
    subscriptionId?: string;
  };
  testNotification?: unknown;
};

const PORT = Number(process.env.PORT ?? '8080');
const GOOGLE_PLAY_PACKAGE_NAME = process.env.GOOGLE_PLAY_PACKAGE_NAME ?? 'com.nanomarkup.aliolo';
const WORKER_SHARED_SECRET = process.env.WORKER_SHARED_SECRET ?? '';
const WORKER_GOOGLE_PLAY_WEBHOOK_URL = process.env.WORKER_GOOGLE_PLAY_WEBHOOK_URL ?? '';
const WORKER_GOOGLE_PLAY_RECONCILE_CANDIDATES_URL =
  process.env.WORKER_GOOGLE_PLAY_RECONCILE_CANDIDATES_URL ?? '';
const GOOGLE_METADATA_TOKEN_URL =
  'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token';
const GOOGLE_PLAY_SCOPE = 'https://www.googleapis.com/auth/androidpublisher';
const SIGNATURE_HEADER = 'x-aliolo-signature';
const TIMESTAMP_HEADER = 'x-aliolo-timestamp';
const MAX_SIGNATURE_AGE_MS = 5 * 60 * 1000;

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'content-type': 'application/json',
    },
  });
}

async function readRawBody(request: Request): Promise<string> {
  return request.text();
}

async function createSignature(timestamp: string, rawBody: string): Promise<string> {
  return createHmac('sha256', WORKER_SHARED_SECRET)
    .update(`${timestamp}.${rawBody}`)
    .digest('hex');
}

async function createSignedHeaders(rawBody: string): Promise<HeadersInit> {
  const timestamp = Date.now().toString();
  return {
    [TIMESTAMP_HEADER]: timestamp,
    [SIGNATURE_HEADER]: await createSignature(timestamp, rawBody),
    'content-type': 'application/json',
  };
}

async function validateSignature(request: Request, rawBody: string): Promise<boolean> {
  if (!WORKER_SHARED_SECRET) return false;
  const timestamp = request.headers.get(TIMESTAMP_HEADER);
  const signature = request.headers.get(SIGNATURE_HEADER);
  if (!timestamp || !signature) return false;

  const timestampValue = Number(timestamp);
  if (!Number.isFinite(timestampValue)) return false;
  if (Math.abs(Date.now() - timestampValue) > MAX_SIGNATURE_AGE_MS) return false;

  return signature === await createSignature(timestamp, rawBody);
}

async function getGoogleAccessToken(): Promise<string> {
  const response = await fetch(`${GOOGLE_METADATA_TOKEN_URL}?scopes=${encodeURIComponent(GOOGLE_PLAY_SCOPE)}`, {
    headers: {
      'Metadata-Flavor': 'Google',
    },
  });
  const payload = await response.json().catch(() => null) as { access_token?: string } | null;
  if (!response.ok || !payload?.access_token) {
    throw new Error('Could not obtain Google metadata access token');
  }
  return payload.access_token;
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

async function fetchSubscription(
  purchaseToken: string,
  packageName: string,
  productId?: string | null,
): Promise<Verification> {
  const accessToken = await getGoogleAccessToken();
  const response = await fetch(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(packageName)}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`,
    {
      headers: {
        Authorization: `Bearer ${accessToken}`,
        Accept: 'application/json',
      },
    },
  );

  const data = await response.json().catch(() => null) as GoogleSubscriptionPurchaseV2 | GoogleApiErrorResponse | null;
  if (!response.ok || !data || isGoogleApiErrorResponse(data)) {
    throw new Error((data as GoogleApiErrorResponse | null)?.error?.message ?? 'Google Play verification failed');
  }
  const verifiedData = data;

  const lineItem =
    verifiedData.lineItems?.find((item) => item.productId === productId) ??
    verifiedData.lineItems?.[0];
  const verifiedProductId = lineItem?.productId ?? productId ?? null;
  if (productId && verifiedProductId && verifiedProductId !== productId) {
    const error = new Error('Google Play purchase does not match the requested product');
    (error as Error & { status?: number }).status = 409;
    throw error;
  }

  const periodEnd = lineItem?.expiryTime ?? null;
  return {
    packageName,
    purchaseToken,
    productId: verifiedProductId,
    status: statusFromGoogleState(verifiedData.subscriptionState, periodEnd),
    subscriptionState: verifiedData.subscriptionState ?? null,
    periodStart: verifiedData.startTime ?? null,
    periodEnd,
    willRenew: lineItem?.autoRenewingPlan?.autoRenewEnabled ?? null,
    environment: verifiedData.testPurchase ? 'test' : 'production',
    externalSubscriptionId: purchaseToken,
    externalCustomerId:
      verifiedData.externalAccountIdentifiers?.obfuscatedExternalAccountId ??
      verifiedData.externalAccountIdentifiers?.externalAccountId ??
      null,
    externalTransactionId:
      lineItem?.latestSuccessfulOrderId ?? verifiedData.latestOrderId ?? null,
    rawPayload: verifiedData,
  };
}

async function forwardToWorker(payload: WorkerWebhookPayload): Promise<void> {
  if (!WORKER_GOOGLE_PLAY_WEBHOOK_URL) {
    throw new Error('WORKER_GOOGLE_PLAY_WEBHOOK_URL is not configured');
  }
  const rawBody = JSON.stringify(payload);
  const response = await fetch(WORKER_GOOGLE_PLAY_WEBHOOK_URL, {
    method: 'POST',
    headers: await createSignedHeaders(rawBody),
    body: rawBody,
  });
  if (!response.ok) {
    throw new Error(`Worker webhook rejected Google Play update with status ${response.status}`);
  }
}

async function fetchReconcileCandidates(limit = 200): Promise<ReconcileCandidate[]> {
  if (!WORKER_GOOGLE_PLAY_RECONCILE_CANDIDATES_URL) {
    return [];
  }
  const response = await fetch(
    `${WORKER_GOOGLE_PLAY_RECONCILE_CANDIDATES_URL}?limit=${encodeURIComponent(String(limit))}`,
    {
      method: 'GET',
      headers: await createSignedHeaders(''),
    },
  );
  const payload = await response.json().catch(() => null) as
    | { subscriptions?: ReconcileCandidate[]; error?: string }
    | null;
  if (!response.ok || !payload?.subscriptions) {
    throw new Error(payload?.error ?? 'Could not load reconcile candidates from Worker');
  }
  return payload.subscriptions;
}

function decodePubSubMessage(data: string | undefined): RtdnPayload | null {
  if (!data) return null;
  const raw = Buffer.from(data, 'base64').toString('utf8');
  return JSON.parse(raw) as RtdnPayload;
}

function rtdnEventType(notificationType: number | undefined): string {
  return `rtdn_subscription_${notificationType ?? 'unknown'}`;
}

async function handleVerify(request: Request): Promise<Response> {
  const rawBody = await readRawBody(request);
  if (!await validateSignature(request, rawBody)) {
    return json(401, { error: 'Invalid verifier signature' });
  }

  const body = JSON.parse(rawBody || '{}') as VerifyRequest;
  if (!body.purchaseToken) {
    return json(400, { error: 'purchaseToken is required' });
  }

  try {
    const verification = await fetchSubscription(
      body.purchaseToken,
      body.packageName ?? GOOGLE_PLAY_PACKAGE_NAME,
      body.productId ?? null,
    );
    return json(200, verification);
  } catch (error) {
    const status = (error as Error & { status?: number }).status ?? 502;
    return json(status, { error: error instanceof Error ? error.message : 'Verification failed' });
  }
}

async function handleRtdn(request: Request): Promise<Response> {
  const rawBody = await readRawBody(request);
  const body = JSON.parse(rawBody || '{}') as PubSubPushBody;
  const payload = decodePubSubMessage(body.message?.data);
  if (!payload) return json(400, { error: 'Invalid Pub/Sub payload' });
  if (payload.testNotification) {
    return json(200, { success: true, ignored: true, reason: 'test_notification' });
  }

  const notification = payload.subscriptionNotification;
  const purchaseToken = notification?.purchaseToken;
  if (!purchaseToken) {
    return json(200, { success: true, ignored: true, reason: 'missing_purchase_token' });
  }

  try {
    const verification = await fetchSubscription(
      purchaseToken,
      payload.packageName ?? GOOGLE_PLAY_PACKAGE_NAME,
      notification?.subscriptionId ?? null,
    );
    await forwardToWorker({
      eventId: `google_rtdn_${body.message?.messageId ?? purchaseToken}_${notification?.notificationType ?? 'unknown'}`,
      eventType: rtdnEventType(notification?.notificationType),
      source: 'rtdn',
      verification,
      rawEvent: payload,
      purchaseToken,
      productId: notification?.subscriptionId ?? verification.productId,
      packageName: payload.packageName ?? GOOGLE_PLAY_PACKAGE_NAME,
      googleObfuscatedAccountId: verification.externalCustomerId,
      externalNotificationId: body.message?.messageId ?? null,
    });
    return json(200, { success: true });
  } catch (error) {
    return json(502, { error: error instanceof Error ? error.message : 'RTDN processing failed' });
  }
}

async function handleReconcile(request: Request): Promise<Response> {
  const rawBody = await readRawBody(request);
  if (!await validateSignature(request, rawBody)) {
    return json(401, { error: 'Invalid verifier signature' });
  }

  const body = JSON.parse(rawBody || '{}') as { subscriptions?: ReconcileCandidate[]; limit?: number };
  const candidates = body.subscriptions?.length
    ? body.subscriptions
    : await fetchReconcileCandidates(body.limit ?? 200);

  let processed = 0;
  let failed = 0;
  for (const candidate of candidates) {
    try {
      const verification = await fetchSubscription(
        candidate.purchaseToken,
        candidate.packageName ?? GOOGLE_PLAY_PACKAGE_NAME,
        candidate.productId ?? null,
      );
      await forwardToWorker({
        eventId: `google_reconcile_${candidate.purchaseToken}_${Date.now()}`,
        eventType: 'reconcile_verify',
        source: 'reconcile',
        verification,
        rawEvent: {
          source: 'reconcile',
          candidate,
        },
        userId: candidate.userId ?? null,
        purchaseToken: candidate.purchaseToken,
        productId: candidate.productId ?? verification.productId,
        packageName: candidate.packageName ?? GOOGLE_PLAY_PACKAGE_NAME,
        googleObfuscatedAccountId:
          candidate.googleObfuscatedAccountId ?? verification.externalCustomerId,
      });
      processed += 1;
    } catch {
      failed += 1;
    }
  }

  return json(200, {
    success: true,
    processed,
    failed,
  });
}

const server = createServer(async (req, res) => {
  const request = new Request(`http://localhost${req.url}`, {
    method: req.method,
    headers: req.headers as HeadersInit,
    body:
      req.method === 'GET' || req.method === 'HEAD'
        ? undefined
        : (Readable.toWeb(req) as ReadableStream),
  } as RequestInit);

  let response: Response;
  try {
    if (request.method === 'POST' && request.url.endsWith('/google-play/verify')) {
      response = await handleVerify(request);
    } else if (request.method === 'POST' && request.url.endsWith('/google-play/rtdn')) {
      response = await handleRtdn(request);
    } else if (request.method === 'POST' && request.url.endsWith('/google-play/reconcile')) {
      response = await handleReconcile(request);
    } else {
      response = json(404, { error: 'Not found' });
    }
  } catch (error) {
    response = json(500, { error: error instanceof Error ? error.message : 'Unexpected error' });
  }

  res.statusCode = response.status;
  response.headers.forEach((value, key) => {
    res.setHeader(key, value);
  });
  const responseText = await response.text();
  res.end(responseText);
});

server.listen(PORT, () => {
  console.log(`google-play-verifier listening on :${PORT}`);
});
