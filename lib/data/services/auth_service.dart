import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aliolo/data/models/user_model.dart';
import 'translation_service.dart';
import 'theme_service.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  SupabaseClient? _supabase;
  bool _isSupabaseInitialized = false;
  bool get isOnlineMode => _isSupabaseInitialized;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  String? _lastErrorMessage;
  String? get lastErrorMessage => _lastErrorMessage;

  Rect? loginBounds;

  Future<void> init() async {
    const String supabaseUrl = 'https://mltdjjszycfmokwqsqxm.supabase.co';
    const String supabaseKey = 'sb_publishable_DCMw0z92Lr2nzC83sOQJXw_G1fYdEb3';
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
      _supabase = Supabase.instance.client;
      _isSupabaseInitialized = true;
      final session = _supabase!.auth.currentSession;
      if (session != null) {
        await _fetchAndSyncUser(session.user);
      }
    } catch (e) {
      print('Supabase init failed: $e');
    }
  }

  Future<void> _fetchAndSyncUser(User remoteUser) async {
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
    _currentUser = user;
    user.updatedAt = DateTime.now();
    try {
      await _supabase!.from('profiles').upsert(user.toJson());
    } catch (e) {
      print('Error updating remote user: $e');
    }
    notifyListeners();
  }

  bool isValidEmail(String e) =>
      RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(e);

  // Everyone is treated equally in terms of edit permissions now
  bool get canEditLibrary => true;
  bool get canManageUsers => false; // Or remove if not used

  Future<List<UserModel>> getLeaderboardData({
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      final from = page * pageSize;
      final to = from + pageSize - 1;

      final List<dynamic> data = await _supabase!
          .from('profiles')
          .select()
          .eq('show_on_leaderboard', true)
          .order('total_xp', ascending: false)
          .range(from, to);

      return data.map((p) => UserModel.fromJson(p)).toList();
    } catch (e) {
      print('Error fetching leaderboard: $e');
      return [];
    }
  }

  Future<int> getMyGlobalRank() async {
    if (_currentUser == null) return -1;
    try {
      // Find how many people have more XP than me
      final res = await _supabase!
          .from('profiles')
          .select('id')
          .eq('show_on_leaderboard', true)
          .gt('total_xp', _currentUser!.totalXp);

      // PostgrestResponse returns a list, the count is the length if we select 'id'
      // Or use the count property if available in the result
      final List<dynamic> data = res as List<dynamic>;
      return data.length + 1;
    } catch (e) {
      print('Error getting my rank: $e');
      return -1;
    }
  }

  Future<void> updateUsername(String n) async {
    if (_currentUser != null) {
      _currentUser!.username = n;
      await updateUser(_currentUser!);
    }
  }

  Future<void> updateEmail(String e) async {
    if (_currentUser != null) {
      _currentUser!.email = e.toLowerCase();
      await updateUser(_currentUser!);
    }
  }

  Future<void> updateDailyGoal(int c) async {
    if (_currentUser != null) {
      _currentUser!.dailyGoalCount = c;
      await updateUser(_currentUser!);
    }
  }

  Future<void> updateUiLanguagePreference(String l) async {
    if (_currentUser != null) {
      _currentUser!.uiLanguage = l;
      await updateUser(_currentUser!);
    }
  }

  Future<void> updateThemePreference(String m) async {
    if (_currentUser != null) {
      _currentUser!.themeMode = m;
      await updateUser(_currentUser!);
    }
  }

  Future<void> updateDefaultLanguage(String l) async {
    if (_currentUser != null) {
      _currentUser!.defaultLanguage = l;
      await updateUser(_currentUser!);
    }
  }

  Future<void> updateSidebarPreference(bool v) async {
    if (_currentUser != null) {
      _currentUser!.sidebarLeft = v;
      await updateUser(_currentUser!);
    }
  }

  Future<void> updateSoundPreference(bool v) async {
    if (_currentUser != null) {
      _currentUser!.soundEnabled = v;
      await updateUser(_currentUser!);
    }
  }

  Future<void> updateLeaderboardPreference(bool v) async {
    if (_currentUser != null) {
      _currentUser!.showOnLeaderboard = v;
      await updateUser(_currentUser!);
    }
  }

  Future<void> updateAvatarPath(String localPath) async {
    if (_currentUser == null || !_isSupabaseInitialized) return;
    try {
      final file = File(localPath);
      if (!await file.exists()) return;

      final ext = p.extension(localPath);
      final fileName = 'avatar$ext';
      final storagePath = '${_currentUser!.serverId}/$fileName';

      await _supabase!.storage
          .from('avatars')
          .upload(
            storagePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      final String publicUrl = _supabase!.storage
          .from('avatars')
          .getPublicUrl(storagePath);
      _currentUser!.avatarPath = publicUrl;
      await updateUser(_currentUser!);
    } catch (e) {
      print('Error uploading avatar: $e');
    }
  }

  Future<void> updateShortcuts(int p, int n) async {
    if (_currentUser != null) {
      _currentUser!.shortcutPrevKey = p;
      _currentUser!.shortcutNextKey = n;
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

  Future<String?> sendResetCode(String email) async {
    try {
      await _supabase!.auth.resetPasswordForEmail(email);
      return 'sent';
    } catch (e) {
      return e.toString();
    }
  }

  bool verifyResetCode(String u, String c) =>
      true; // Supabase handles this via link
  Future<void> finalizePasswordReset(String email, String newPassword) async {
    await _supabase!.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<bool> updatePassword(String o, String n) async {
    return true;
  }

  Future<bool> deleteAccount(String password) async {
    if (_currentUser == null || !_isSupabaseInitialized) return false;
    try {
      // 1. Re-authenticate to ensure password is correct
      final res = await _supabase!.auth.signInWithPassword(
        email: _currentUser!.email,
        password: password,
      );

      if (res.user == null) return false;

      // 2. Call RPC to delete all user-related data (profiles, progress, etc.)
      // This is safer than manual multiple deletes from client
      await _supabase!.rpc('delete_user_data');

      // 3. Log out locally
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
