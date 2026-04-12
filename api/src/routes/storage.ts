import { Hono } from 'hono';
import type { AppEnv } from '../types';

const router = new Hono<AppEnv>();

const ADMIN_ID = 'f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac';

router.post('/api/upload/:bucket/:path{.+}', async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const bucketName = c.req.param('bucket');
    const filePath = c.req.param('path'); // e.g. cards/ID/images/lang/file.jpg
    
    // Security Check for Card Media
    if (filePath.startsWith('cards/')) {
        const segments = filePath.split('/');
        const cardId = segments[1];
        
        if (cardId) {
            try {
                const card: any = await c.env.DB.prepare(
                    "SELECT owner_id FROM cards WHERE id = ?"
                ).bind(cardId).first();

                if (card) {
                    // If card belongs to Admin, only Admin can upload
                    if (card.owner_id === ADMIN_ID && user.id !== ADMIN_ID) {
                        return c.json({ error: 'Forbidden: Official cards are read-only' }, 403);
                    }
                    // If card belongs to someone else, only owner (or Admin) can upload
                    if (card.owner_id !== user.id && user.id !== ADMIN_ID) {
                        return c.json({ error: 'Forbidden: You do not own this card' }, 403);
                    }
                }
            } catch (e) {
                // If card doesn't exist yet, we allow the upload (e.g. during creation)
            }
        }
    }

    let bucket: R2Bucket;
    if (bucketName === 'card_images' || bucketName === 'card_audio' || bucketName === 'card_videos' || bucketName === 'feedback_attachments' || bucketName === 'aliolo-media') {
        bucket = c.env.MEDIA;
    } else if (bucketName === 'avatars') {
        bucket = c.env.AVATARS;
    } else {
        return c.json({ error: 'Bucket not found' }, 404);
    }

    // New logic: if it's already a full path (like cards/...), we use it as is.
    // Legacy support: if it's just a file in a sub-bucket, we prepend the bucket name.
    const r2Path = filePath.startsWith('cards/') || bucketName === 'avatars' ? filePath : `${bucketName}/${filePath}`;
    
    const body = await c.req.arrayBuffer();
    const contentType = c.req.header('Content-Type') || 'application/octet-stream';

    try {
        await bucket.put(r2Path, body, {
            httpMetadata: { contentType }
        });
        const url = `${new URL(c.req.url).origin}/storage/v1/object/public/${bucketName}/${filePath}`;
        return c.json({ url });
    } catch (e: any) {
        return c.json({ error: e.message }, 500);
    }
});

router.delete('/api/storage/:bucket/:path{.+}', async (c) => {
    const user = c.get("user");
    if (!user) return c.json({ error: 'Unauthorized' }, 401);

    const bucketName = c.req.param('bucket');
    const filePath = c.req.param('path');
    
    // Security Check for Card Media
    if (filePath.startsWith('cards/')) {
        const segments = filePath.split('/');
        const cardId = segments[1];
        
        if (cardId) {
            try {
                const card: any = await c.env.DB.prepare(
                    "SELECT owner_id FROM cards WHERE id = ?"
                ).bind(cardId).first();

                if (card) {
                    if (card.owner_id === ADMIN_ID && user.id !== ADMIN_ID) {
                        return c.json({ error: 'Forbidden: Official cards are read-only' }, 403);
                    }
                    if (card.owner_id !== user.id && user.id !== ADMIN_ID) {
                        return c.json({ error: 'Forbidden: You do not own this card' }, 403);
                    }
                }
            } catch (e) {}
        }
    }

    let bucket: R2Bucket;
    if (bucketName === 'card_images' || bucketName === 'card_audio' || bucketName === 'card_videos' || bucketName === 'feedback_attachments' || bucketName === 'aliolo-media') {
        bucket = c.env.MEDIA;
    } else if (bucketName === 'avatars') {
        bucket = c.env.AVATARS;
    } else {
        return c.json({ error: 'Bucket not found' }, 404);
    }

    const r2Path = filePath.startsWith('cards/') || bucketName === 'avatars' ? filePath : `${bucketName}/${filePath}`;

    try {
        await bucket.delete(r2Path);
        return c.json({ success: true });
    } catch (e: any) {
        return c.json({ error: e.message }, 500);
    }
});

// Media Serving (Public)
router.get('/storage/v1/object/public/:bucket/:path{.+}', async (c) => {
  const bucketName = c.req.param('bucket');
  const path = c.req.param('path');
  
  let bucket: R2Bucket;
  if (bucketName === 'card_images' || bucketName === 'card_audio' || bucketName === 'card_videos' || bucketName === 'feedback_attachments' || bucketName === 'aliolo-media') {
    bucket = c.env.MEDIA;
  } else if (bucketName === 'avatars') {
    bucket = c.env.AVATARS;
  } else {
    return c.text('Bucket not found', 404);
  }

  const r2Path = path.startsWith('cards/') || bucketName === 'avatars' ? path : `${bucketName}/${path}`;
  
  const object = await bucket.get(r2Path);
  if (!object) return c.text('Object not found', 404);

  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set('etag', object.httpEtag);
  headers.set('Cache-Control', 'public, max-age=31536000');

  return new Response(object.body, { headers });
});

export default router;