import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aliolo/data/models/user_model.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/core/di/service_locator.dart';
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
      final session = _supabase!.auth.currentSession;
      if (session != null && session.user != null) {
        await _fetchAndSyncUser(session.user!);
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
        _currentUser = UserModel.fromJson(remoteData);
        // Ensure email is consistent from remoteUser if missing or different
        _currentUser!.email = remoteUser.email!.toLowerCase();
        ThemeService().setThemeFromString(_currentUser!.themeMode);
        ThemeService().setPrimaryColor(
          ThemeService.fromHex(_currentUser!.mainColor),
        );
      } else {
        _currentUser = UserModel(
          username:
              remoteUser.userMetadata?['username'] ??
              remoteUser.email!.split('@')[0],
          email: remoteUser.email!.toLowerCase(),
          serverId: remoteUser.id,
          uiLanguage: TranslationService().currentLocale.languageCode,
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
      if (res.user != null) {
        await _fetchAndSyncUser(res.user!);
      }
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
    notifyListeners();
  }

  Future<void> updateUser(UserModel user) async {
    if (_supabase == null) return;
    _currentUser = user;
    user.updatedAt = DateTime.now();
    try {
      await _supabase!.from('profiles').upsert(user.toJson());
    } catch (e) {
      print('Error updating remote user: $e');
    }
    notifyListeners();
  }

  Future<void> updateMainColor(String hexColor) async {
    if (_currentUser == null || _currentUser!.serverId == null || _supabase == null) return;
    try {
      await _supabase!.from('profiles').update({'main_color': hexColor}).eq(
        'id',
        _currentUser!.serverId!,
      );
      _currentUser!.mainColor = hexColor;
      ThemeService().setPrimaryColor(ThemeService.fromHex(hexColor));
      notifyListeners();
    } catch (e) {
      print('Error updating main color: $e');
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
          .order('total_xp', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      return data.map((json) => UserModel.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching leaderboard: $e');
      return [];
    }
  }

  Future<int?> getMyGlobalRank() async {
    if (_currentUser == null || _currentUser!.serverId == null) return null;
    try {
      // Very simple way to get rank for a medium amount of users
      final List<dynamic> data = await _supabase!
          .from('profiles')
          .select('id')
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

  Future<void> updateSidebarPreference(bool left) async {
    if (_currentUser != null) {
      _currentUser!.sidebarLeft = left;
      await updateUser(_currentUser!);
    }
  }

  Future<void> updateThemePreference(String mode) async {
    if (_currentUser != null) {
      _currentUser!.themeMode = mode;
      await updateUser(_currentUser!);
    }
  }

  Future<void> updateSoundPreference(bool enabled) async {
    if (_currentUser != null) {
      _currentUser!.soundEnabled = enabled;
      await updateUser(_currentUser!);
    }
  }

  Future<void> updateLeaderboardPreference(bool show) async {
    if (_currentUser != null) {
      _currentUser!.showOnLeaderboard = show;
      await updateUser(_currentUser!);
    }
  }

  Future<void> updateDefaultLanguage(String lang) async {
    if (_currentUser != null) {
      _currentUser!.defaultLanguage = lang;
      await updateUser(_currentUser!);
    }
  }

  Future<void> updateDailyGoal(int count) async {
    if (_currentUser != null) {
      _currentUser!.dailyGoalCount = count;
      await updateUser(_currentUser!);
    }
  }

  Future<void> updateSessionSize(int size) async {
    if (_currentUser != null) {
      _currentUser!.sessionSize = size;
      await updateUser(_currentUser!);
    }
  }

  Future<void> updateOptionsCount(int count) async {
    if (_currentUser != null) {
      _currentUser!.optionsCount = count;
      await updateUser(_currentUser!);
    }
  }

  Future<void> updateShortcuts(int prev, int next) async {
    if (_currentUser != null) {
      _currentUser!.shortcutPrevKey = prev;
      _currentUser!.shortcutNextKey = next;
      await updateUser(_currentUser!);
    }
  }

  Future<void> updateUiLanguagePreference(String lang) async {
    if (_currentUser != null) {
      _currentUser!.uiLanguage = lang;
      await updateUser(_currentUser!);
    }
  }

  Future<void> updateUsername(String newName) async {
    if (_currentUser != null) {
      _currentUser!.username = newName;
      await updateUser(_currentUser!);
    }
  }

  Future<void> updateAvatarPath(XFile image) async {
    if (_currentUser == null) return;
    try {
      final fileName =
          'avatar_${_currentUser!.serverId}_${DateTime.now().millisecondsSinceEpoch}${p.extension(image.path)}';
      final storagePath = 'avatars/$fileName';

      final bytes = await image.readAsBytes();
      await _supabase!.storage.from('user_assets').uploadBinary(
        storagePath,
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );

      final String publicUrl = _supabase!.storage
          .from('user_assets')
          .getPublicUrl(storagePath);

      _currentUser!.avatarPath = publicUrl;
      await updateUser(_currentUser!);
    } catch (e) {
      print('Error uploading avatar: $e');
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
    try {
      // For security, Supabase doesn't allow users to delete themselves easily via client SDK
      // Usually, you'd call an Edge Function or mark as is_deleted.
      // We will mark as deleted in profiles and sign out.
      _currentUser!.isDeleted = true;
      await updateUser(_currentUser!);
      await logout();
      _currentUser = null;
      notifyListeners();
      return true;
    } catch (e) {
      print('Error deleting account: $e');
      return false;
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    return [];
  }
}
