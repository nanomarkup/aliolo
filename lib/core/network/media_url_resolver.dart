import 'cloudflare_client.dart';

class MediaUrlResolver {
  static const String supabaseDomain = 'mltdjjszycfmokwqsqxm.supabase.co';
  static const String workerDomain = 'aliolo-backend.vitalii-e07.workers.dev';
  static String get cloudflareBaseUrl => CloudflareHttpClient.baseUrl;

  /// Translates a Supabase Storage URL or legacy Worker URL to the Cloudflare Worker proxy URL.
  /// Example:
  /// https://mltdjjszycfmokwqsqxm.supabase.co/storage/v1/object/public/aliolo-media/file.jpg
  /// ->
  /// https://aliolo.com/storage/v1/object/public/aliolo-media/file.jpg
  static String resolve(String? url) {
    if (url == null || url.isEmpty) return '';
    return url
        .replaceFirst('https://$supabaseDomain', cloudflareBaseUrl)
        .replaceFirst('https://$workerDomain', cloudflareBaseUrl);
  }

  static List<String> resolveList(List<String>? urls) {
    if (urls == null) return [];
    return urls.map((u) => resolve(u)).toList();
  }
}
