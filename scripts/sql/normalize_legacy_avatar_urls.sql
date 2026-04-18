UPDATE profiles
SET avatar_url = replace(
  avatar_url,
  '/storage/v1/object/public/avatars/',
  '/storage/v1/object/public/aliolo-media/avatars/'
)
WHERE avatar_url LIKE '%/storage/v1/object/public/avatars/%';
