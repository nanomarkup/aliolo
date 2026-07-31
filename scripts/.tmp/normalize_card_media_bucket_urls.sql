UPDATE cards
SET
  images_base = replace(replace(replace(replace(
    images_base,
    '/storage/v1/object/public/card_images/',
    '/storage/v1/object/public/aliolo-media/'
  ), '/storage/v1/object/public/card_audio/',
    '/storage/v1/object/public/aliolo-media/'
  ), '/storage/v1/object/public/card_videos/',
    '/storage/v1/object/public/aliolo-media/'
  ), '/storage/v1/object/public/feedback_attachments/',
    '/storage/v1/object/public/aliolo-media/'
  ),
  images_local = replace(replace(replace(replace(
    images_local,
    '/storage/v1/object/public/card_images/',
    '/storage/v1/object/public/aliolo-media/'
  ), '/storage/v1/object/public/card_audio/',
    '/storage/v1/object/public/aliolo-media/'
  ), '/storage/v1/object/public/card_videos/',
    '/storage/v1/object/public/aliolo-media/'
  ), '/storage/v1/object/public/feedback_attachments/',
    '/storage/v1/object/public/aliolo-media/'
  ),
  audio = replace(replace(replace(replace(
    audio,
    '/storage/v1/object/public/card_images/',
    '/storage/v1/object/public/aliolo-media/'
  ), '/storage/v1/object/public/card_audio/',
    '/storage/v1/object/public/aliolo-media/'
  ), '/storage/v1/object/public/card_videos/',
    '/storage/v1/object/public/aliolo-media/'
  ), '/storage/v1/object/public/feedback_attachments/',
    '/storage/v1/object/public/aliolo-media/'
  ),
  audios = replace(replace(replace(replace(
    audios,
    '/storage/v1/object/public/card_images/',
    '/storage/v1/object/public/aliolo-media/'
  ), '/storage/v1/object/public/card_audio/',
    '/storage/v1/object/public/aliolo-media/'
  ), '/storage/v1/object/public/card_videos/',
    '/storage/v1/object/public/aliolo-media/'
  ), '/storage/v1/object/public/feedback_attachments/',
    '/storage/v1/object/public/aliolo-media/'
  ),
  video = replace(replace(replace(replace(
    video,
    '/storage/v1/object/public/card_images/',
    '/storage/v1/object/public/aliolo-media/'
  ), '/storage/v1/object/public/card_audio/',
    '/storage/v1/object/public/aliolo-media/'
  ), '/storage/v1/object/public/card_videos/',
    '/storage/v1/object/public/aliolo-media/'
  ), '/storage/v1/object/public/feedback_attachments/',
    '/storage/v1/object/public/aliolo-media/'
  ),
  videos = replace(replace(replace(replace(
    videos,
    '/storage/v1/object/public/card_images/',
    '/storage/v1/object/public/aliolo-media/'
  ), '/storage/v1/object/public/card_audio/',
    '/storage/v1/object/public/aliolo-media/'
  ), '/storage/v1/object/public/card_videos/',
    '/storage/v1/object/public/aliolo-media/'
  ), '/storage/v1/object/public/feedback_attachments/',
    '/storage/v1/object/public/aliolo-media/'
  ),
  updated_at = CURRENT_TIMESTAMP
WHERE
  images_base LIKE '%/storage/v1/object/public/card_images/%'
  OR images_base LIKE '%/storage/v1/object/public/card_audio/%'
  OR images_base LIKE '%/storage/v1/object/public/card_videos/%'
  OR images_base LIKE '%/storage/v1/object/public/feedback_attachments/%'
  OR images_local LIKE '%/storage/v1/object/public/card_images/%'
  OR images_local LIKE '%/storage/v1/object/public/card_audio/%'
  OR images_local LIKE '%/storage/v1/object/public/card_videos/%'
  OR images_local LIKE '%/storage/v1/object/public/feedback_attachments/%'
  OR audio LIKE '%/storage/v1/object/public/card_images/%'
  OR audio LIKE '%/storage/v1/object/public/card_audio/%'
  OR audio LIKE '%/storage/v1/object/public/card_videos/%'
  OR audio LIKE '%/storage/v1/object/public/feedback_attachments/%'
  OR audios LIKE '%/storage/v1/object/public/card_images/%'
  OR audios LIKE '%/storage/v1/object/public/card_audio/%'
  OR audios LIKE '%/storage/v1/object/public/card_videos/%'
  OR audios LIKE '%/storage/v1/object/public/feedback_attachments/%'
  OR video LIKE '%/storage/v1/object/public/card_images/%'
  OR video LIKE '%/storage/v1/object/public/card_audio/%'
  OR video LIKE '%/storage/v1/object/public/card_videos/%'
  OR video LIKE '%/storage/v1/object/public/feedback_attachments/%'
  OR videos LIKE '%/storage/v1/object/public/card_images/%'
  OR videos LIKE '%/storage/v1/object/public/card_audio/%'
  OR videos LIKE '%/storage/v1/object/public/card_videos/%'
  OR videos LIKE '%/storage/v1/object/public/feedback_attachments/%';
