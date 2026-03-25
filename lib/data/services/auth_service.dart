import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
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

  UserModel? get currentUser => _currentUser;
  String? get lastErrorMessage => _lastErrorMessage;

  bool get _isSupabaseInitialized => _supabase != null;

  Future<void> init() async {
    try {
      _supabase = Supabase.instance.client;
      
      // Listen to auth state changes (e.g. email confirmed, sign in/out)
      _supabase!.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;

        if (session != null &&
            (event == AuthChangeEvent.signedIn ||
                event == AuthChangeEvent.userUpdated)) {
          // ONLY sync if email is confirmed (or if it's not a new registration that needs confirmation)
          if (session.user.emailConfirmedAt != null) {
            _fetchAndSyncUser(session.user);
          } else {
            // If session exists but email not confirmed, we don't treat them as logged in
            _currentUser = null;
            notifyListeners();
          }
        } else if (event == AuthChangeEvent.signedOut) {
          _currentUser = null;
          notifyListeners();
        }
      });

      final session = _supabase!.auth.currentSession;
      if (session != null && session.user.emailConfirmedAt != null) {
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

        // Reset daily progress if it's a new day
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
            // Update immediately in DB to sync state
            await updateUser(_currentUser!);
          }
        }

        // Ensure email is consistent from remoteUser if missing or different
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
              remoteUser.email!.split('@')[0],
          email: remoteUser.email!.toLowerCase(),
          serverId: remoteUser.id,
          uiLanguage: TranslationService().currentLocale.languageCode,
          mainPillarId: 8,
        );
        await updateUser(_currentUser!);
      }
      notifyListeners();
    } catch (e) {
      print('Error fetching user profile: $e');
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
      // Explicitly logout to clear any session from signUp, 
      // preventing automatic navigation to main page before confirmation.
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
      // Whitelist ONLY confirmed columns from user's provided schema
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
      print('Error updating user profile: $e');
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
      print('Error updating main pillar color: $e');
    }
  }

  bool isValidEmail(String e) =>
      RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(e);

  // Everyone is treated equally in terms of edit permissions now
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
      print('Error fetching leaderboard: $e');
      return [];
    }
  }

  Future<int?> getMyGlobalRank() async {
    if (_currentUser == null || _currentUser!.serverId == null || !_currentUser!.showOnLeaderboard) return null;
    try {
      // Very simple way to get rank for a medium amount of users
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
      print('Error getting my rank: $e');
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
      print('Error patching profile with $changes: $e');
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
      // The email in our profiles table will be synced next time the user logs in
      // or we can optimisticly update it if we want, but usually we wait for confirmation.
    } catch (e) {
      _lastErrorMessage = e.toString();
      rethrow;
    }
  }

  Future<void> updatePassword(String oldPassword, String newPassword) async {
    if (_supabase == null || _currentUser == null) return;
    try {
      // 1. Verify old password by attempting a silent sign-in
      await _supabase!.auth.signInWithPassword(
        email: _currentUser!.email,
        password: oldPassword,
      );

      // 2. If successful, update to the new password
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
      print('Error uploading avatar: $e');
    }
  }

  Future<void> deleteAvatar() async {
    if (_currentUser == null || _currentUser!.avatarPath == null) return;
    try {
      // Extract file name from public URL if possible to delete from storage
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
      print('Error deleting avatar: $e');
      // Even if storage delete fails, clear the path in profile
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

  Future<void> finalizePasswordReset(String email, String newPassword) async {
    try {
      await _supabase!.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      _lastErrorMessage = e.toString();
      rethrow;
    }
  }

  Future<bool> deleteAccount(String password) async {
    if (_currentUser == null) return false;
    _lastErrorMessage = null;
    try {
      // Re-verify the password by attempting a silent sign-in
      await _supabase!.auth.signInWithPassword(
        email: _currentUser!.email,
        password: password,
      );

      // Call our custom RPC function which handles cascading deletion of all user data
      // including auth.users record (via SECURITY DEFINER).
      await _supabase!.rpc('delete_user_account');
      
      await logout();
      _currentUser = null;
      notifyListeners();
      return true;
    } on AuthException catch (ae) {
      print('Auth error during account deletion: ${ae.message}');
      _lastErrorMessage = ae.message;
      return false;
    } catch (e) {
      print('Error deleting account: $e');
      _lastErrorMessage = e.toString();
      return false;
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    return [];
  }
}
