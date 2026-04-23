import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aliolo/core/utils/file_stub.dart'
    if (dart.library.html) 'dart:html'
    as html;
import 'package:aliolo/data/models/user_model.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/core/utils/logger.dart';
import 'package:dio/dio.dart';

import 'package:aliolo/core/network/cloudflare_client.dart';
import 'package:aliolo/core/di/service_locator.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _cfClient = getIt<CloudflareHttpClient>();
  UserModel? _currentUser;
  String? _lastErrorMessage;
  bool _isPasswordRecoveryFlow = false;
  bool _isInviteFlow = false;
  String? _inviteToken;
  String? _initialUrl;
  String? _recoveryFlowType;
  String? _currentSessionEmail;

  UserModel? get currentUser => _currentUser;
  String? get lastErrorMessage => _lastErrorMessage;
  bool get isPasswordRecoveryFlow => _isPasswordRecoveryFlow;
  bool get isInviteFlow => _isInviteFlow;
  String? get inviteToken => _inviteToken;
  String? get recoveryFlowType => _recoveryFlowType;
  String? get currentSessionEmail =>
      _currentSessionEmail ?? _currentUser?.email;

  Future<void> init({String? manualUrl, String? inviteToken}) async {
    try {
      _initialUrl = manualUrl ?? (kIsWeb ? html.window.location.href : null);

      if (inviteToken != null) {
        _isInviteFlow = true;
        _inviteToken = inviteToken;
        // Verify token and get email before showing UI
        final data = await verifyInvite(inviteToken);
        _currentSessionEmail = data?['email'];

        // Clear the URL parameter so it doesn't re-trigger on logout/refresh
        if (kIsWeb) {
          html.window.history.replaceState({}, '', '/');
        }

        await _cfClient.clearSession();
        _currentUser = null;
        notifyListeners();
        return;
      }

      if (kIsWeb && _initialUrl != null) {
        final uri = Uri.parse(_initialUrl!);

        if (uri.queryParameters.containsKey('type')) {
          _isPasswordRecoveryFlow = true;
          _recoveryFlowType = uri.queryParameters['type'];
          _currentSessionEmail = uri.queryParameters['email'];
          // Clear URL
          html.window.history.replaceState({}, '', '/');
        }

        // Backup check if invite was missed in main()
        if (uri.queryParameters.containsKey('invite')) {
          _isInviteFlow = true;
          _inviteToken = uri.queryParameters['invite'];
          print('Invite token detected via URL query: $_inviteToken');
          // Clear URL
          html.window.history.replaceState({}, '', '/');

          await _cfClient.clearSession();
          _currentUser = null;
          notifyListeners();
          return;
        }
      }

      // Initial session check from Cloudflare
      final profileRes = await _cfClient.client.get('/api/auth/me');
      if (profileRes.statusCode == 200 && profileRes.data['user'] != null) {
        _currentUser = UserModel.fromJson(profileRes.data['user']);

        // Daily completion reset logic (moved to client side but synced to D1)
        if (_currentUser!.lastActiveDate != null) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final lastLocal = _currentUser!.lastActiveDate!.toLocal();
          final lastDayParsed = DateTime(
            lastLocal.year,
            lastLocal.month,
            lastLocal.day,
          );

          if (today.isAfter(lastDayParsed)) {
            _currentUser!.dailyCompletions = 0;
            _currentUser!.dailyGoalCount = _currentUser!.nextDailyGoal;
            await updateUser(_currentUser!);
          }
        }

        ThemeService().setThemeFromString(_currentUser!.themeMode);
        ThemeService().setPrimaryColorFromPillar(_currentUser!.mainPillarId);
        notifyListeners();
      }

      if (kIsWeb && _initialUrl != null) {
        // Handle potential recovery/invite types from URL if needed
      }
    } catch (e) {
      AppLogger.log('AuthService.init() failed: $e');
    }
    notifyListeners();
  }

  Future<bool> requestOtp(String email) async {
    _lastErrorMessage = null;
    try {
      final response = await _cfClient.client.post(
        '/api/auth/request-otp',
        data: {'email': email},
      );
      return response.statusCode == 200;
    } catch (e) {
      _lastErrorMessage = e.toString();
      return false;
    }
  }

  Future<bool> verifyOtp(String email, String code) async {
    _lastErrorMessage = null;
    try {
      final response = await _cfClient.client.post(
        '/api/auth/verify-otp',
        data: {'email': email, 'code': code},
      );
      return response.statusCode == 200;
    } catch (e) {
      _lastErrorMessage = e.toString();
      return false;
    }
  }

  Future<Map<String, String>?> verifyInvite(String token) async {
    _lastErrorMessage = null;
    try {
      final response = await _cfClient.client.get(
        '/api/auth/verify-invite',
        queryParameters: {'token': token},
      );
      if (response.statusCode == 200) {
        return {
          'email': response.data['email'],
          'token': response.data['token'],
        };
      }
      return null;
    } catch (e) {
      _lastErrorMessage = e.toString();
      return null;
    }
  }

  Future<void> createUserWithInvite(
    String username,
    String email,
    String password,
    String inviteToken,
  ) async {
    _lastErrorMessage = null;
    try {
      final response = await _cfClient.client.post(
        '/api/auth/signup-invite',
        data: {
          'username': username,
          'email': email,
          'password': password,
          'invite_token': inviteToken,
        },
      );

      if (response.statusCode == 200) {
        if (response.data['session_id'] != null) {
          await _cfClient.setSession(response.data['session_id']);
        }
        _isInviteFlow = false;
        _inviteToken = null;
        await refreshUser();
      }
    } catch (e) {
      _lastErrorMessage = e.toString();
      rethrow;
    }
  }

  Future<void> createUser(
    String username,
    String email,
    String password,
  ) async {
    _lastErrorMessage = null;
    final cleanEmail = email.trim().toLowerCase();
    try {
      final response = await _cfClient.client.post(
        '/api/auth/signup',
        data: {'username': username, 'email': cleanEmail, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final String sessionId = data['session_id'];
        await _cfClient.setSession(sessionId);
        await refreshUser();
      } else {
        _lastErrorMessage = response.data['error'] ?? 'Signup failed';
        throw Exception(_lastErrorMessage);
      }
    } catch (e) {
      _lastErrorMessage = e.toString();
      rethrow;
    }
  }

  Future<bool> login(String identifier, String password) async {
    _lastErrorMessage = null;
    final String email = identifier.trim().toLowerCase();

    try {
      final response = await _cfClient.client.post(
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final String sessionId = data['session_id'];
        await _cfClient.setSession(sessionId);
        await refreshUser();
        return true;
      } else {
        _lastErrorMessage = response.data['error'] ?? 'Login failed';
        return false;
      }
    } catch (e) {
      AppLogger.log('Cloudflare login failed: $e');
      _lastErrorMessage = e.toString();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _cfClient.client.post('/api/auth/logout');
      await _cfClient.clearSession();
    } catch (e) {
      AppLogger.log('Cloudflare logout error: $e');
    }

    _currentUser = null;
    _lastErrorMessage = null;
    _isPasswordRecoveryFlow = false;
    _isInviteFlow = false;
    _inviteToken = null;
    _recoveryFlowType = null;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    try {
      final profileRes = await _cfClient.client.get('/api/auth/me');
      if (profileRes.statusCode == 200 && profileRes.data['user'] != null) {
        _currentUser = UserModel.fromJson(profileRes.data['user']);
        ThemeService().setThemeFromString(_currentUser!.themeMode);
        ThemeService().setPrimaryColorFromPillar(_currentUser!.mainPillarId);
        notifyListeners();
      }
    } catch (e) {
      AppLogger.log('AuthService: refreshUser error: $e');
    }
  }

  Future<void> updateUser(UserModel user) async {
    if (user.serverId == null) return;

    final now = DateTime.now();
    user.updatedAt = now;
    user.lastActiveDate ??= now;
    _currentUser = user;

    try {
      final data = user.toJson();
      await _cfClient.client.post('/api/auth/update', data: data);
      notifyListeners();
    } catch (e) {
      AppLogger.log('AuthService: updateUser error: $e');
    }
  }

  Future<void> _patchCurrentUser(Map<String, dynamic> data) async {
    if (_currentUser?.serverId == null) return;
    try {
      await _cfClient.client.post('/api/auth/update', data: data);
      notifyListeners();
    } catch (e) {
      AppLogger.log('AuthService: _patchCurrentUser error: $e');
    }
  }

  Future<void> updateUsername(String name) async {
    if (_currentUser != null) {
      _currentUser!.username = name;
      await _patchCurrentUser({'username': name});
    }
  }

  Future<void> updateThemeMode(String mode) async {
    if (_currentUser != null) {
      _currentUser!.themeMode = mode;
      ThemeService().setThemeFromString(mode);
      await _patchCurrentUser({'theme_mode': mode});
    }
  }

  Future<void> updateUILanguage(String lang) async {
    if (_currentUser != null) {
      _currentUser!.uiLanguage = lang;
      await _patchCurrentUser({'ui_language': lang});
    }
  }

  Future<void> updateMainPillar(int pillarId) async {
    if (_currentUser != null) {
      _currentUser!.mainPillarId = pillarId;
      ThemeService().setPrimaryColorFromPillar(pillarId);
      await _patchCurrentUser({'main_pillar_id': pillarId});
    }
  }

  Future<void> updateOptionsCount(int count) async {
    if (_currentUser != null) {
      _currentUser!.optionsCount = count;
      await _patchCurrentUser({'options_count': count});
    }
  }

  Future<void> updateLearnSessionSize(int size) async {
    if (_currentUser != null) {
      _currentUser!.learnSessionSize = size;
      await _patchCurrentUser({'learn_session_size': size});
    }
  }

  Future<void> updateTestSessionSize(int size) async {
    if (_currentUser != null) {
      _currentUser!.testSessionSize = size;
      await _patchCurrentUser({'test_session_size': size});
    }
  }

  Future<void> updateTestMode(String mode) async {
    if (_currentUser != null) {
      _currentUser!.testMode = mode;
      await _patchCurrentUser({'test_mode': mode});
    }
  }

  Future<void> updateLearnAutoplayDelay(int seconds) async {
    if (_currentUser != null) {
      _currentUser!.learnAutoplayDelaySeconds = seconds;
      await _patchCurrentUser({'learn_autoplay_delay_seconds': seconds});
    }
  }

  Future<void> updateDailyGoal(int goal) async {
    if (_currentUser != null) {
      _currentUser!.dailyGoalCount = goal;
      await _patchCurrentUser({'daily_goal_count': goal});
    }
  }

  Future<void> updateNextDailyGoal(int goal) async {
    if (_currentUser != null) {
      _currentUser!.nextDailyGoal = goal;
      await _patchCurrentUser({'next_daily_goal': goal});
    }
  }

  Future<void> updateShowDocumentation(bool show) async {
    if (_currentUser != null) {
      _currentUser!.showDocumentation = show;
      await _patchCurrentUser({'show_documentation': show});
    }
  }

  Future<void> updateDefaultLanguage(String lang) async {
    if (_currentUser != null) {
      _currentUser!.defaultLanguage = lang.toUpperCase();
      await _patchCurrentUser({'default_language': lang.toLowerCase()});
    }
  }

  Future<void> updateThemePreference(String mode) async {
    await updateThemeMode(mode);
  }

  Future<void> updateDocumentationPreference(bool val) async {
    await updateShowDocumentation(val);
  }

  Future<void> updateMainColorFromPillar(int pillarId) async {
    await updateMainPillar(pillarId);
  }

  Future<void> updateAvatarPath(XFile image) async {
    if (_currentUser == null) return;
    try {
      // Delete old avatars if they exist
      if (_currentUser!.avatarPath != null) {
        try {
          final oldUri = Uri.parse(_currentUser!.avatarPath!);
          final oldFileName = oldUri.pathSegments.last.split('?').first;
          await _cfClient.client.delete(
            '/api/storage/aliolo-media/avatars/$oldFileName',
          );
        } catch (e) {
          AppLogger.log(
            'AuthService: error deleting old avatar during update: $e',
          );
        }
      }
      if (_currentUser!.avatarOriginalPath != null) {
        try {
          final oldUri = Uri.parse(_currentUser!.avatarOriginalPath!);
          final oldFileName = oldUri.pathSegments.last.split('?').first;
          await _cfClient.client.delete(
            '/api/storage/aliolo-media/avatars/$oldFileName',
          );
        } catch (e) {
          AppLogger.log(
            'AuthService: error deleting old original avatar during update: $e',
          );
        }
      }

      final ext = p.extension(image.name).toLowerCase();
      final originalFileName = '${_currentUser!.serverId}_original$ext';
      final optimizedFileName = '${_currentUser!.serverId}$ext';
      final originalBytes = await image.readAsBytes();

      // Upload original
      final originalResponse = await _cfClient.client.post(
        '/api/upload/aliolo-media/avatars/$originalFileName',
        data: Stream.fromIterable([originalBytes]),
        options: Options(
          headers: {
            Headers.contentTypeHeader: 'image/${ext.replaceAll('.', '')}',
            Headers.contentLengthHeader: originalBytes.length,
          },
        ),
      );

      // Create optimized version (small)
      Uint8List? optimizedBytes;
      final img.Image? decoded = img.decodeImage(originalBytes);
      if (decoded != null) {
        final img.Image resized = img.copyResize(decoded, width: 200);
        // We use original extension to pick encoder
        if (ext == '.png') {
          optimizedBytes = Uint8List.fromList(img.encodePng(resized));
        } else if (ext == '.jpg' || ext == '.jpeg') {
          optimizedBytes = Uint8List.fromList(
            img.encodeJpg(resized, quality: 85),
          );
        } else {
          // Fallback to WebP or Jpg if unknown
          optimizedBytes = Uint8List.fromList(
            img.encodeJpg(resized, quality: 85),
          );
        }
      } else {
        // If decoding failed, just use original as fallback for optimized
        optimizedBytes = originalBytes;
      }

      // Upload optimized
      final optimizedResponse = await _cfClient.client.post(
        '/api/upload/aliolo-media/avatars/$optimizedFileName',
        data: Stream.fromIterable([optimizedBytes]),
        options: Options(
          headers: {
            Headers.contentTypeHeader: 'image/${ext.replaceAll('.', '')}',
            Headers.contentLengthHeader: optimizedBytes.length,
          },
        ),
      );

      if (optimizedResponse.statusCode == 200 &&
          originalResponse.statusCode == 200) {
        final String optimizedUrl = optimizedResponse.data['url'];
        final String originalUrl = originalResponse.data['url'];
        final bustOptimizedUrl =
            '$optimizedUrl?t=${DateTime.now().millisecondsSinceEpoch}';
        final bustOriginalUrl =
            '$originalUrl?t=${DateTime.now().millisecondsSinceEpoch}';

        await _patchCurrentUser({
          'avatar_url': bustOptimizedUrl,
          'avatar_original_url': bustOriginalUrl,
        });
        _currentUser!.avatarPath = bustOptimizedUrl;
        _currentUser!.avatarOriginalPath = bustOriginalUrl;
        notifyListeners();
      }
    } catch (e) {
      AppLogger.log('AuthService: updateAvatarPath error: $e');
    }
  }

  Future<void> deleteAvatar() async {
    if (_currentUser == null) return;
    try {
      if (_currentUser!.avatarPath != null) {
        final uri = Uri.parse(_currentUser!.avatarPath!);
        final fileName = uri.pathSegments.last.split('?').first;
        await _cfClient.client.delete(
          '/api/storage/aliolo-media/avatars/$fileName',
        );
      }
      if (_currentUser!.avatarOriginalPath != null) {
        final uri = Uri.parse(_currentUser!.avatarOriginalPath!);
        final fileName = uri.pathSegments.last.split('?').first;
        await _cfClient.client.delete(
          '/api/storage/aliolo-media/avatars/$fileName',
        );
      }

      await _patchCurrentUser({
        'avatar_url': null,
        'avatar_original_url': null,
      });
      _currentUser!.avatarPath = null;
      _currentUser!.avatarOriginalPath = null;
      notifyListeners();
    } catch (e) {
      AppLogger.log('AuthService: deleteAvatar error: $e');
    }
  }

  Future<bool> sendResetCode(String email) async {
    _lastErrorMessage = null;
    try {
      final response = await _cfClient.client.post(
        '/api/auth/request-password-reset',
        data: {'email': email},
      );
      return response.statusCode == 200;
    } catch (e) {
      _lastErrorMessage = e.toString();
      return false;
    }
  }

  Future<bool> finalizePasswordReset(
    String email,
    String code,
    String newPassword,
  ) async {
    _lastErrorMessage = null;
    try {
      final response = await _cfClient.client.post(
        '/api/auth/reset-password',
        data: {'email': email, 'code': code, 'password': newPassword},
      );
      return response.statusCode == 200;
    } catch (e) {
      _lastErrorMessage = e.toString();
      return false;
    }
  }

  Future<void> updatePassword(String newPassword) async {
    _lastErrorMessage = null;
    try {
      final response = await _cfClient.client.post(
        '/api/auth/update-password',
        data: {'new_password': newPassword},
      );
      if (response.statusCode != 200) {
        throw Exception(response.data['error'] ?? 'Failed to update password');
      }
    } catch (e) {
      _lastErrorMessage = e.toString();
      rethrow;
    }
  }

  void clearRecoveryFlow() {
    _isPasswordRecoveryFlow = false;
    _recoveryFlowType = null;
    notifyListeners();
  }

  bool verifyResetCode(String email, String code) => true;

  bool isValidEmail(String e) =>
      RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(e);

  Future<void> updateEmail(String email) async {
    await _patchCurrentUser({'email': email});
  }

  Future<bool> requestEmailChange(String newEmail, String password) async {
    _lastErrorMessage = null;
    try {
      final response = await _cfClient.client.post(
        '/api/auth/request-email-change',
        data: {'new_email': newEmail, 'password': password},
      );
      return response.statusCode == 200;
    } catch (e) {
      _lastErrorMessage = _handleDioError(e);
      return false;
    }
  }

  Future<bool> verifyEmailChange(String newEmail, String code) async {
    _lastErrorMessage = null;
    try {
      final response = await _cfClient.client.post(
        '/api/auth/verify-email-change',
        data: {'new_email': newEmail, 'code': code},
      );
      if (response.statusCode == 200) {
        await refreshUser();
        return true;
      }
      return false;
    } catch (e) {
      _lastErrorMessage = _handleDioError(e);
      return false;
    }
  }

  Future<bool> deleteAccount(String password) async {
    _lastErrorMessage = null;
    try {
      final response = await _cfClient.client.post(
        '/api/auth/delete',
        data: {'password': password},
      );
      if (response.statusCode == 200) {
        _currentUser = null;
        await _cfClient.clearSession();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _lastErrorMessage = _handleDioError(e);
      return false;
    }
  }

  Future<void> updateSidebarPreference(bool val) async {
    if (_currentUser != null) {
      _currentUser!.sidebarLeft = val;
      await _patchCurrentUser({'sidebar_left': val});
    }
  }

  Future<void> updateSoundPreference(bool val) async {
    if (_currentUser != null) {
      _currentUser!.soundEnabled = val;
      await _patchCurrentUser({'sound_enabled': val});
    }
  }

  Future<void> updateLeaderboardPreference(bool val) async {
    if (_currentUser != null) {
      _currentUser!.showOnLeaderboard = val;
      await _patchCurrentUser({'show_on_leaderboard': val});
    }
  }

  Future<void> updateAutoPlayPreference(bool val) async {
    if (_currentUser != null) {
      _currentUser!.autoPlayEnabled = val;
      await _patchCurrentUser({'auto_play_enabled': val});
    }
  }

  Future<void> updateMediaAutoPlayMuted(bool val) async {
    if (_currentUser != null) {
      _currentUser!.mediaAutoPlayMuted = val;
      await _patchCurrentUser({'media_auto_play_muted': val});
    }
  }

  Future<void> patchProgress({
    required double dailyCompletions,
    required int totalXp,
    required int currentStreak,
    required int maxStreak,
    required DateTime lastActiveDate,
  }) async {
    if (_currentUser != null) {
      _currentUser!.dailyCompletions = dailyCompletions;
      _currentUser!.totalXp = totalXp;
      _currentUser!.currentStreak = currentStreak;
      _currentUser!.maxStreak = maxStreak;
      _currentUser!.lastActiveDate = lastActiveDate;

      await _patchCurrentUser({
        'daily_completions': dailyCompletions,
        'total_xp': totalXp,
        'current_streak': currentStreak,
        'max_streak': maxStreak,
        'last_active_date': lastActiveDate.toUtc().toIso8601String(),
      });
    }
  }

  Future<String> inviteUserByEmail(String email, {String? senderId}) async {
    try {
      final response = await _cfClient.client.post(
        '/api/auth/invite',
        data: {'email': email},
      );
      if (response.statusCode == 200) {
        return response.data['message'] ?? 'Invitation sent!';
      }
      return 'Failed to send invitation';
    } catch (e) {
      return _handleDioError(e);
    }
  }

  Future<List<UserModel>> getLeaderboardData({
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      final response = await _cfClient.client.get(
        '/api/leaderboard',
        queryParameters: {'page': page, 'pageSize': pageSize},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => UserModel.fromJson(json)).toList();
      }
    } catch (e) {
      AppLogger.log('AuthService: getLeaderboardData error: $e');
    }
    return [];
  }

  Future<int?> getMyGlobalRank() async {
    if (_currentUser?.serverId == null) return null;
    try {
      final response = await _cfClient.client.get('/api/leaderboard/rank');
      if (response.statusCode == 200) {
        return response.data['rank'];
      }
    } catch (e) {
      AppLogger.log('AuthService: getMyGlobalRank error: $e');
    }
    return null;
  }

  String _handleDioError(dynamic e) {
    if (e is DioException) {
      if (e.response != null && e.response!.data is Map) {
        return e.response!.data['error'] ?? e.message ?? 'An error occurred';
      }
      return e.message ?? 'Connection error';
    }
    return e.toString();
  }
}
