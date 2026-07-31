#!/bin/bash
set -euo pipefail

BASE_URL="${ALIOLO_PRODUCTION_URL:-https://aliolo.com}"

HTTP_STATUS="$(curl --silent --output /dev/null --write-out '%{http_code}' http://aliolo.com/)"
HTTP_LOCATION="$(curl --silent --head http://aliolo.com/ | tr -d '\r' | awk 'tolower($1) == "location:" { print $2 }')"
if [[ "$HTTP_STATUS" != "301" && "$HTTP_STATUS" != "308" ]] || [[ "$HTTP_LOCATION" != "https://aliolo.com/" ]]; then
  echo "Expected http://aliolo.com/ to redirect permanently to https://aliolo.com/" >&2
  exit 1
fi

curl --fail --silent --show-error --location \
  --retry 5 --retry-delay 2 --retry-all-errors \
  "$BASE_URL/" >/dev/null

LANDING_HTML="$(curl --fail --silent --show-error "$BASE_URL/")"
if [[ "$LANDING_HTML" != *'<link rel="icon" type="image/webp" href="/app_icon.webp">'* ]]; then
  echo "Production landing page is missing its favicon link" >&2
  exit 1
fi

ROBOTS_TXT="$(curl --fail --silent --show-error "$BASE_URL/robots.txt")"
if [[ "$ROBOTS_TXT" != *'Sitemap: https://aliolo.com/sitemap.xml'* ]] ||
   [[ "$ROBOTS_TXT" == *'Disallow: /login'* ]] ||
   [[ "$ROBOTS_TXT" == *'Disallow: /pay'* ]]; then
  echo "Production robots.txt contains incorrect crawl directives" >&2
  exit 1
fi

SITEMAP_XML="$(curl --fail --silent --show-error "$BASE_URL/sitemap.xml")"
if [[ "$SITEMAP_XML" != *'<loc>https://aliolo.com/</loc>'* ]] ||
   [[ "$SITEMAP_XML" == *'<changefreq>'* ]] ||
   [[ "$SITEMAP_XML" == *'<priority>'* ]]; then
  echo "Production sitemap.xml failed SEO checks" >&2
  exit 1
fi

LOGIN_HTML="$(curl --fail --silent --show-error "$BASE_URL/login")"
if [[ "$LOGIN_HTML" != *'<meta name="robots" content="noindex,nofollow">'* ]]; then
  echo "Production login shell is missing noindex" >&2
  exit 1
fi

curl --fail --silent --show-error --location \
  --retry 5 --retry-delay 2 --retry-all-errors \
  "$BASE_URL/api/pillars" >/dev/null

curl --fail --silent --show-error --location \
  --retry 5 --retry-delay 2 --retry-all-errors \
  "$BASE_URL/api/languages" >/dev/null

echo "Production smoke checks passed for $BASE_URL"
