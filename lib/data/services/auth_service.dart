import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:html' as html if (dart.library.io) 'package:aliolo/core/utils/file_stub.dart';
import 'package:aliolo/data/models/user_model.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/core/utils/logger.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  SupabaseClient? _supabase;
  UserModel? _currentUser;
  String? _lastErrorMessage;
  bool _isPasswordRecoveryFlow = false;
  String? _initialUrl;

  UserModel? get currentUser => _currentUser;
  String? get lastErrorMessage => _lastErrorMessage;
  bool get isPasswordRecoveryFlow => _isPasswordRecoveryFlow;

  bool get _isSupabaseInitialized => _supabase != null;

  Future<void> init({String? manualUrl}) async {
    try {
      _supabase = Supabase.instance.client;
      _initialUrl = manualUrl ?? (kIsWeb ? html.window.location.href : null);
      
      // 1. PRE-CHECK: Detect recovery/invite/signup flows from URL
      if (kIsWeb && _initialUrl != null) {
        final uri = Uri.parse(_initialUrl!);
        bool flowDetected = false;
        
        // Check hash first (Implicit flow)
        final hash = uri.fragment;
        if (hash.contains('access_token=')) {
          final params = Uri.splitQueryString(hash);
          final type = params['type'];
          if (type == 'recovery' || type == 'invite' || type == 'signup') {
            flowDetected = true;
          }
        } 
        
        // Check query params (PKCE flow)
        if (!flowDetected) {
          final type = uri.queryParameters['type'];
          final code = uri.queryParameters['code'];
          if (code != null || type == 'recovery' || type == 'invite' || type == 'signup') {
             flowDetected = true;
          }
        }

        if (flowDetected) {
          _isPasswordRecoveryFlow = true;
          // IMPORTANT: If we detect an auth flow but already have a session, 
          // it means another user might be logged in. We MUST logout to avoid session conflict.
          if (_supabase!.auth.currentSession != null) {
            await _supabase!.auth.signOut();
          }
        }
      }

      // 2. Listen to auth state changes
      _supabase!.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;

        if (event == AuthChangeEvent.passwordRecovery) {
          _isPasswordRecoveryFlow = true;
          notifyListeners();
        }

        if (session != null &&
            (event == AuthChangeEvent.signedIn ||
                event == AuthChangeEvent.userUpdated ||
                event == AuthChangeEvent.initialSession)) {
          if (session.user.emailConfirmedAt != null || _isPasswordRecoveryFlow) {
            _fetchAndSyncUser(session.user);
          } else {
            _currentUser = null;
            notifyListeners();
          }
        } else if (event == AuthChangeEvent.signedOut) {
          _currentUser = null;
          notifyListeners();
        }
      });

      // 3. MANUAL FALLBACK: If no session but we have tokens in URL, force-establish it
      if (kIsWeb && _supabase!.auth.currentSession == null && _initialUrl != null) {
        if (_initialUrl!.contains('access_token=') || _initialUrl!.contains('code=')) {
          try {
            await _supabase!.auth.getSessionFromUrl(Uri.parse(_initialUrl!));
          } catch (e) {
            // MANUAL EXTRACTION FALLBACK for Implicit Flow
            if (_initialUrl!.contains('access_token=')) {
               final uri = Uri.parse(_initialUrl!);
               final fragment = uri.fragment;
               final params = Uri.splitQueryString(fragment);
               final refresh = params['refresh_token'];
               if (refresh != null) {
                  try {
                    await _supabase!.auth.setSession(refresh);
                  } catch (e2) {
                    // Ignore silently if fallback fails
                  }
               }
            }
          }
        }
      }

      final session = _supabase!.auth.currentSession;
      if (session != null && (session.user.emailConfirmedAt != null || _isPasswordRecoveryFlow)) {
        await _fetchAndSyncUser(session.user);
      }
    } catch (e) {
      AppLogger.log('AuthService.init() failed: $e');
    }
    notifyListeners();
  }

  Future<void> _fetchAndSyncUser(User remoteUser) async {
    if (_supabase == null) return;
    try {
      final remoteData =
          await _supabase!
              .from('profiles')
              .select()
              .eq('id', remoteUser.id)
              .maybeSingle();

      if (remoteData != null) {
        final user = UserModel.fromJson(remoteData);
        if (user.isDeleted) {
          await logout();
          _lastErrorMessage = 'account_deleted';
          return;
        }
        _currentUser = user;

        if (_currentUser!.lastActiveDate != null) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final lastLocal = _currentUser!.lastActiveDate!.toLocal();
          final lastDay = DateTime(
            lastLocal.year,
            lastLocal.month,
            lastLocal.day,
          );

          if (today.isAfter(lastDay)) {
            _currentUser!.dailyCompletions = 0;
            _currentUser!.dailyGoalCount = _currentUser!.nextDailyGoal;
            await updateUser(_currentUser!);
          }
        }

        if (_currentUser!.email != remoteUser.email!.toLowerCase()) {
          _currentUser!.email = remoteUser.email!.toLowerCase();
          await updateUser(_currentUser!);
        }

        ThemeService().setThemeFromString(_currentUser!.themeMode);
        ThemeService().setPrimaryColorFromPillar(_currentUser!.mainPillarId);
      } else {
        _currentUser = UserModel(
          username:
              remoteUser.userMetadata?['username'] ??
              remoteUser.email!.toLowerCase().split('@')[0],
          email: remoteUser.email!.toLowerCase(),
          serverId: remoteUser.id,
          uiLanguage: TranslationService().currentLocale.languageCode,
          mainPillarId: 8,
        );
        try {
          await updateUser(_currentUser!);
        } catch (e) {
          // Optional profile creation failure (RLS or other)
        }
      }
      notifyListeners();
    } catch (e) {
      // Error fetching profile handled silently
    }
  }

  Future<void> createUser(
    String username,
    String email,
    String password,
  ) async {
    _lastErrorMessage = null;
    if (_supabase == null) {
      _lastErrorMessage = "Supabase not initialized";
      return;
    }
    final cleanEmail = email.trim().toLowerCase();
    try {
      final res = await _supabase!.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {'username': username},
      );
      await logout();
    } on AuthException catch (e) {
      _lastErrorMessage = e.message;
      rethrow;
    } catch (e) {
      _lastErrorMessage = e.toString();
      rethrow;
    }
  }

  Future<bool> login(String identifier, String password) async {
    _lastErrorMessage = null;
    if (_supabase == null) {
      _lastErrorMessage = "Supabase not initialized";
      return false;
    }
    final String email = identifier.trim().toLowerCase();
    try {
      final res = await _supabase!.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.user != null) {
        await _fetchAndSyncUser(res.user!);
        return true;
      }
    } on AuthException catch (e) {
      _lastErrorMessage = e.message;
      return false;
    } catch (e) {
      _lastErrorMessage = e.toString();
      return false;
    }
    return false;
  }

  Future<void> logout() async {
    if (_isSupabaseInitialized) await _supabase!.auth.signOut();
    _currentUser = null;
    _lastErrorMessage = null;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (_supabase == null) return;
    final user = _supabase!.auth.currentUser;
    if (user != null) {
      await _fetchAndSyncUser(user);
    }
  }

  Future<void> updateUser(UserModel user) async {
    if (_supabase == null || user.serverId == null) return;

    final now = DateTime.now();
    user.updatedAt = now;
    user.lastActiveDate ??= now;
    _currentUser = user;

    try {
      final data = {
        'username': user.username,
        'email': user.email,
        'total_xp': user.totalXp,
        'current_streak': user.currentStreak,
        'max_streak': user.maxStreak,
        'theme_mode': user.themeMode,
        'ui_language': user.uiLanguage,
        'daily_goal_count': user.dailyGoalCount,
        'sidebar_left': user.sidebarLeft,
        'sound_enabled': user.soundEnabled,
        'show_on_leaderboard': user.showOnLeaderboard,
        'learn_session_size': user.learnSessionSize,
        'test_session_size': user.testSessionSize,
        'options_count': user.optionsCount,
        'avatar_url': user.avatarPath,
        'default_language': user.defaultLanguage.toLowerCase(),
        'main_pillar_id': user.mainPillarId,
        'last_active_date': user.lastActiveDate?.toUtc().toIso8601String(),
        'next_daily_goal': user.nextDailyGoal,
        'daily_completions': user.dailyCompletions,
        'auto_play_enabled': user.autoPlayEnabled,
        'is_deleted': user.isDeleted,
        'updated_at': user.updatedAt?.toUtc().toIso8601String(),
      };

      final List<dynamic> res = await _supabase!
          .from('profiles')
          .update(data)
          .eq('id', user.serverId!)
          .select('id');

      if (res.isEmpty) {
        data['id'] = user.serverId!;
        await _supabase!.from('profiles').upsert(data);
      }
    } catch (e) {
      // Profile update error logged or handled
    }
    notifyListeners();
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
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }

  Future<void> updateMainColorFromPillar(int pillarId) async {
    if (_currentUser == null ||
        _currentUser!.serverId == null ||
        _supabase == null) {
      return;
    }
    try {
      await _supabase!
          .from('profiles')
          .update({'main_pillar_id': pillarId})
          .eq('id', _currentUser!.serverId!);
      _currentUser!.mainPillarId = pillarId;
      ThemeService().setPrimaryColorFromPillar(pillarId);
      notifyListeners();
    } catch (e) {
      // Error handling
    }
  }

  bool isValidEmail(String e) =>
      RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(e);

  bool get canEditLibrary => true;
  bool get canManageUsers => false;

  Future<List<UserModel>> getLeaderboardData({
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      final List<dynamic> data = await _supabase!
          .from('profiles')
          .select()
          .eq('show_on_leaderboard', true)
          .order('total_xp', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      return data.map((json) => UserModel.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<int?> getMyGlobalRank() async {
    if (_currentUser == null || _currentUser!.serverId == null || !_currentUser!.showOnLeaderboard) return null;
    try {
      final List<dynamic> data = await _supabase!
          .from('profiles')
          .select('id')
          .eq('show_on_leaderboard', true)
          .order('total_xp', ascending: false);

      for (int i = 0; i < data.length; i++) {
        if (data[i]['id'] == _currentUser!.serverId) return i + 1;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _patchCurrentUser(Map<String, dynamic> changes) async {
    if (_supabase == null || _currentUser?.serverId == null) return;

    try {
      await _supabase!
          .from('profiles')
          .update(changes)
          .eq('id', _currentUser!.serverId!);
    } catch (e) {
      // Silence patch errors
    }
    notifyListeners();
  }

  Future<void> updateSidebarPreference(bool left) async {
    if (_currentUser != null) {
      _currentUser!.sidebarLeft = left;
      await _patchCurrentUser({'sidebar_left': left});
    }
  }

  Future<void> updateThemePreference(String mode) async {
    if (_currentUser != null) {
      _currentUser!.themeMode = mode;
      await _patchCurrentUser({'theme_mode': mode});
    }
  }

  Future<void> updateSoundPreference(bool enabled) async {
    if (_currentUser != null) {
      _currentUser!.soundEnabled = enabled;
      await _patchCurrentUser({'sound_enabled': enabled});
    }
  }

  Future<void> updateAutoPlayPreference(bool enabled) async {
    if (_currentUser != null) {
      _currentUser!.autoPlayEnabled = enabled;
      await _patchCurrentUser({'auto_play_enabled': enabled});
    }
  }

  Future<void> updateLeaderboardPreference(bool show) async {
    if (_currentUser != null) {
      _currentUser!.showOnLeaderboard = show;
      await _patchCurrentUser({'show_on_leaderboard': show});
    }
  }

  Future<void> updateDefaultLanguage(String lang) async {
    if (_currentUser != null) {
      _currentUser!.defaultLanguage = lang;
      await _patchCurrentUser({'default_language': lang});
    }
  }

  Future<void> updateNextDailyGoal(int count) async {
    if (_currentUser != null) {
      _currentUser!.nextDailyGoal = count;
      await _patchCurrentUser({'next_daily_goal': count});
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

  Future<void> updateOptionsCount(int count) async {
    if (_currentUser != null) {
      _currentUser!.optionsCount = count;
      await _patchCurrentUser({'options_count': count});
    }
  }

  Future<void> updateUiLanguagePreference(String lang) async {
    if (_currentUser != null) {
      _currentUser!.uiLanguage = lang;
      await _patchCurrentUser({'ui_language': lang});
    }
  }

  Future<void> updateUsername(String newName) async {
    if (_currentUser != null) {
      _currentUser!.username = newName;
      await _patchCurrentUser({'username': newName});
    }
  }

  Future<void> updateEmail(String newEmail) async {
    if (_supabase == null || _currentUser == null) return;
    try {
      await _supabase!.auth.updateUser(UserAttributes(email: newEmail));
    } catch (e) {
      _lastErrorMessage = e.toString();
      rethrow;
    }
  }

  Future<void> updatePassword(String oldPassword, String newPassword) async {
    if (_supabase == null || _currentUser == null) return;
    try {
      await _supabase!.auth.signInWithPassword(
        email: _currentUser!.email,
        password: oldPassword,
      );
      await _supabase!.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (ae) {
      _lastErrorMessage = ae.message;
      rethrow;
    } catch (e) {
      _lastErrorMessage = e.toString();
      rethrow;
    }
  }
  Future<void> updateAvatarPath(XFile image) async {
    if (_currentUser == null) return;
    try {
      final fileName =
          'avatar_${_currentUser!.serverId}_${DateTime.now().millisecondsSinceEpoch}${p.extension(image.path)}';
      final storagePath = 'avatars/$fileName';

      final bytes = await image.readAsBytes();
      await _supabase!.storage
          .from('avatars')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final String publicUrl = _supabase!.storage
          .from('avatars')
          .getPublicUrl(storagePath);

      _currentUser!.avatarPath = publicUrl;
      await updateUser(_currentUser!);
      notifyListeners();
    } catch (e) {
      // Silent error for avatar upload failure
    }
  }

  Future<void> deleteAvatar() async {
    if (_currentUser == null || _currentUser!.avatarPath == null) return;
    try {
      final uri = Uri.parse(_currentUser!.avatarPath!);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final fileName = pathSegments.last;
        await _supabase!.storage.from('avatars').remove(['avatars/$fileName']);
      }

      _currentUser!.avatarPath = null;
      await updateUser(_currentUser!);
      notifyListeners();
    } catch (e) {
      _currentUser!.avatarPath = null;
      await updateUser(_currentUser!);
      notifyListeners();
    }
  }

  Future<void> sendResetCode(String email) async {
    try {
      await _supabase!.auth.resetPasswordForEmail(email);
    } catch (e) {
      _lastErrorMessage = e.toString();
      rethrow;
    }
  }

  bool verifyResetCode(String email, String code) {
    return true;
  }

  void clearRecoveryFlow() {
    _isPasswordRecoveryFlow = false;
    notifyListeners();
  }

  Future<void> finalizePasswordReset(String email, String newPassword) async {
    try {
      var session = _supabase!.auth.currentSession;
      
      if (session == null && kIsWeb && _initialUrl != null) {
        try {
          await _supabase!.auth.getSessionFromUrl(Uri.parse(_initialUrl!));
          session = _supabase!.auth.currentSession;
        } catch (e) {
          final uri = Uri.parse(_initialUrl!);
          final fragment = uri.fragment;
          if (fragment.contains('access_token=')) {
             final params = Uri.splitQueryString(fragment);
             final refresh = params['refresh_token'];
             if (refresh != null) {
                await _supabase!.auth.setSession(refresh);
                session = _supabase!.auth.currentSession;
             }
          }
        }
      }

      if (session == null) {
        throw Exception("Auth session missing. Please try clicking the link in your email again.");
      }
      
      // SAFETY: Ensure provided email matches current session user
      if (email.isNotEmpty && session.user.email?.toLowerCase() != email.toLowerCase()) {
         throw Exception("Session conflict: Logged in as ${session.user.email}, resetting for $email. Logout first.");
      }
      
      await _supabase!.auth.updateUser(UserAttributes(password: newPassword));
      _isPasswordRecoveryFlow = false;
      await _fetchAndSyncUser(session.user);
      
      notifyListeners();
    } catch (e) {
      _lastErrorMessage = e.toString();
      rethrow;
    }
  }

  Future<String> inviteUserByEmail(String email, {String? senderId}) async {
    if (_supabase == null) throw Exception('Supabase not initialized');
    try {
      final response = await _supabase!.functions.invoke(
        'invite-user',
        body: {'email': email, 'senderId': senderId},
      );
      
      if (response.status != 200) {
        throw Exception(response.data['error'] ?? 'Failed to send invite');
      }
      
      final String userId = response.data['data']['user']['id'];
      return userId;
    } catch (e) {
      _lastErrorMessage = e.toString();
      rethrow;
    }
  }

  Future<bool> deleteAccount(String password) async {
    if (_currentUser == null) return false;
    _lastErrorMessage = null;
    try {
      await _supabase!.auth.signInWithPassword(
        email: _currentUser!.email,
        password: password,
      );
      await _supabase!.rpc('delete_user_account');
      await logout();
      _currentUser = null;
      notifyListeners();
      return true;
    } on AuthException catch (ae) {
      _lastErrorMessage = ae.message;
      return false;
    } catch (e) {
      _lastErrorMessage = e.toString();
      return false;
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    return [];
  }
}
