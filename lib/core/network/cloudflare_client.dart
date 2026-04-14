import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CloudflareHttpClient {
  late Dio _dio;
  final _storage = const FlutterSecureStorage();
  
  static const String productionUrl = 'https://aliolo.com';
  // Use 10.0.2.2 for Android Emulator, localhost for Web/Linux
  static String get developmentUrl {
    if (kIsWeb) return 'http://localhost:8787';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8787';
    return 'http://127.0.0.1:8787';
  }

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    
    if (kIsWeb) {
      // On web, if no API_URL is provided, use relative paths.
      // This ensures the app works on aliolo.com, workers.dev, etc.
      return '';
    }
    
    return kReleaseMode ? productionUrl : developmentUrl;
  }

  CloudflareHttpClient() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final sessionId = await _storage.read(key: 'auth_session_id');
        if (sessionId != null) {
          if (kIsWeb) {
            // On Web, browsers handle cookies automatically via standard cookie jars.
            // Setting the 'Cookie' header manually is prohibited (unsafe header).
            options.headers['X-Session-Id'] = sessionId; 
          } else {
            options.headers['Cookie'] = 'auth_session=$sessionId';
          }
        }
        return handler.next(options);
      },
      onResponse: (response, handler) async {
        // Handle session cookie from Lucia if provided in headers
        // Lucia usually sets it via Set-Cookie
        return handler.next(response);
      },
    ));
  }

  Dio get client => _dio;

  Future<void> setSession(String sessionId) async {
    await _storage.write(key: 'auth_session_id', value: sessionId);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: 'auth_session_id');
  }
}
