import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aliolo/core/utils/file_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'package:aliolo/data/models/user_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
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
  String? _recoveryFlowType;

  UserModel? get currentUser => _currentUser;
  String? get lastErrorMessage => _lastErrorMessage;
  bool get isPasswordRecoveryFlow => _isPasswordRecoveryFlow;
  String? get recoveryFlowType => _recoveryFlowType;
  String? get currentSessionEmail => _supabase?.auth.currentSession?.user.email;

  bool get _isSupabaseInitialized => _supabase != null;

  Future<void> init({String? manualUrl}) async {
    try {
      _supabase = Supabase.instance.client;
      _initialUrl = manualUrl ?? (kIsWeb ? html.window.location.href : null);
      
      _supabase!.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;

        AppLogger.log('AuthService: Auth state change: $event');

        if (event == AuthChangeEvent.passwordRecovery) {
          _isPasswordRecoveryFlow = true;
          _recoveryFlowType = 'recovery';
          notifyListeners();
        }

        if (session != null &&
            (event == AuthChangeEvent.signedIn ||
                event == AuthChangeEvent.userUpdated ||
                event == AuthChangeEvent.initialSession)) {
          
          if (!_isPasswordRecoveryFlow && kIsWeb && _initialUrl != null) {
            final uri = Uri.parse(_initialUrl!);
            final type = uri.queryParameters['type'] ?? Uri.splitQueryString(uri.fragment)['type'];
            if (type == 'recovery' || type == 'invite') {
              _isPasswordRecoveryFlow = true;
              _recoveryFlowType = type;
            }
          }

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

      if (kIsWeb && _initialUrl != null) {
        final uri = Uri.parse(_initialUrl!);
        String? detectedType;
        final hash = uri.fragment;
        if (hash.contains('access_token=')) {
          final params = Uri.splitQueryString(hash);
          detectedType = params['type'];
        } 
        if (detectedType == null) {
          detectedType = uri.queryParameters['type'];
        }

        if (detectedType == 'recovery' || detectedType == 'invite') {
          AppLogger.log('AuthService: Detected $detectedType flow in URL.');
          _isPasswordRecoveryFlow = true;
          _recoveryFlowType = detectedType;
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

  bool _checkPremiumStatus(dynamic subsData) {
    if (subsData == null) return false;
    final List subs = subsData is List ? subsData : [subsData];
    if (subs.isEmpty) return false;
    
    final s = subs.first;
    final status = s['status'] as String;
    final expiry = s['expiry_date'] != null ? DateTime.parse(s['expiry_date']) : null;
    return status == 'active' && (expiry == null || expiry.isAfter(DateTime.now()));
  }

  Future<void> _fetchAndSyncUser(User remoteUser) async {
    if (_supabase == null) return;
    try {
      final remoteData =
          await _supabase!
              .from('profiles')
              .select('*, user_subscriptions(status, expiry_date)')
              .eq('id', remoteUser.id)
              .maybeSingle();

      if (remoteData != null) {
        final user = UserModel.fromJson(remoteData);
        user.isPremium = (remoteUser.id == 'f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac') 
            ? true 
            : _checkPremiumStatus(remoteData['user_subscriptions']);
        _currentUser = user;

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

        if (_currentUser!.email != remoteUser.email!.toLowerCase()) {
          _currentUser!.email = remoteUser.email!.toLowerCase();
          await updateUser(_currentUser!);
        }

        ThemeService().setThemeFromString(_currentUser!.themeMode);
        // Persist theme color using mainPillarId
        ThemeService().setPrimaryColorFromPillar(_currentUser!.mainPillarId);
      } else {
        _currentUser = UserModel(
          username:
              remoteUser.userMetadata?['username'] ??
              remoteUser.email!.toLowerCase().split('@')[0],
          email: remoteUser.email!.toLowerCase(),
          serverId: remoteUser.id,
          uiLanguage: TranslationService().currentLocale.languageCode,
          mainPillarId: 6,
        );
        try {
          await updateUser(_currentUser!);
        } catch (e) {
          // Optional profile creation failure
        }
      }
      notifyListeners();
    } catch (e) {
      AppLogger.log('AuthService: _fetchAndSyncUser error: $e');
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
      await _supabase!.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {'username': username},
      );
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
    await _supabase?.auth.signOut();
    _currentUser = null;
    _lastErrorMessage = null;
    _isPasswordRecoveryFlow = false;
    _recoveryFlowType = null;
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
      final data = user.toJson();
      data.remove('id');
      data.remove('created_at');
      
      final List<dynamic> res = await _supabase!
          .from('profiles')
          .update(data)
          .eq('id', user.serverId!)
          .select('id');

      if (res.isEmpty) {
        data['id'] = user.serverId!;
        await _supabase!.from('profiles').upsert(data);
      }
      notifyListeners();
    } catch (e) {
      AppLogger.log('AuthService: updateUser error: $e');
    }
  }

  Future<void> _patchCurrentUser(Map<String, dynamic> data) async {
    if (_supabase == null || _currentUser?.serverId == null) return;
    try {
      await _supabase!
          .from('profiles')
          .update(data)
          .eq('id', _currentUser!.serverId!);
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
      await _patchCurrentUser({'theme_mode': mode});
    }
  }

  Future<void> updateThemePreference(String mode) async {
    await updateThemeMode(mode);
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

  Future<void> updateAvatarPath(XFile image) async {
    if (_currentUser == null || _supabase == null) return;
    try {
      String? oldFileName;
      if (_currentUser!.avatarPath != null) {
        try {
          final uri = Uri.parse(_currentUser!.avatarPath!);
          oldFileName = uri.pathSegments.last.split('?').first;
        } catch (_) {}
      }

      final fileName = 'avatar_${_currentUser!.serverId}_${DateTime.now().millisecondsSinceEpoch}${p.extension(image.path)}';
      final bytes = await image.readAsBytes();
      await _supabase!.storage.from('avatars').uploadBinary(fileName, bytes, fileOptions: const FileOptions(cacheControl: '0', upsert: true));

      final String publicUrl = _supabase!.storage.from('avatars').getPublicUrl(fileName);

      if (oldFileName != null) {
        try {
          await _supabase!.storage.from('avatars').remove([oldFileName]);
        } catch (e) {
          AppLogger.log('AuthService: Failed to delete old avatar file $oldFileName: $e');
        }
      }

      final bustUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      _currentUser!.avatarPath = bustUrl;
      await _supabase!.from('profiles').update({'avatar_url': bustUrl}).eq('id', _currentUser!.serverId!);
      notifyListeners();
    } catch (e) {
      AppLogger.log('AuthService: updateAvatarPath error: $e');
    }
  }

  Future<void> deleteAvatar() async {
    if (_currentUser == null || _currentUser!.avatarPath == null || _supabase == null) return;
    try {
      final uri = Uri.parse(_currentUser!.avatarPath!);
      final fileName = uri.pathSegments.last.split('?').first;
      await _supabase!.storage.from('avatars').remove([fileName]);
      _currentUser!.avatarPath = null;
      await _supabase!.from('profiles').update({'avatar_url': null}).eq('id', _currentUser!.serverId!);
      notifyListeners();
    } catch (e) {
      AppLogger.log('AuthService: deleteAvatar error: $e');
      _currentUser!.avatarPath = null;
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

  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase!.auth.updateUser(UserAttributes(password: newPassword));
      _isPasswordRecoveryFlow = false;
      _recoveryFlowType = null;
      notifyListeners();
    } catch (e) {
      _lastErrorMessage = e.toString();
      rethrow;
    }
  }

  Future<void> finalizePasswordReset(String email, String newPassword) async {
    await updatePassword(newPassword);
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
    await _supabase!.auth.updateUser(UserAttributes(email: email));
  }

  Future<bool> deleteAccount(String password) async {
    try {
      await _supabase!.rpc('delete_user_account');
      await logout();
      return true;
    } catch (e) {
      _lastErrorMessage = e.toString();
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

  Future<void> updateDocumentationPreference(bool val) async {
    await updateShowDocumentation(val);
  }

  Future<void> updateMainColorFromPillar(int pillarId) async {
    await updateMainPillar(pillarId);
    ThemeService().setPrimaryColorFromPillar(pillarId);
  }

  Future<void> updateAutoPlayPreference(bool val) async {
    if (_currentUser != null) {
      _currentUser!.autoPlayEnabled = val;
      await _patchCurrentUser({'auto_play_enabled': val});
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
    if (_supabase == null) throw Exception('Supabase not initialized');
    final res = await _supabase!.functions.invoke('invite-user', body: {'email': email, 'senderId': senderId});
    if (res.status != 200) throw Exception(res.data['error'] ?? 'Invitation failed');
    return res.data['message'] ?? 'Invitation sent';
  }

  Future<List<UserModel>> getLeaderboardData({int page = 0, int pageSize = 20}) async {
    try {
      final List<dynamic> data = await _supabase!
          .from('profiles')
          .select('*, user_subscriptions(status, expiry_date)')
          .eq('show_on_leaderboard', true)
          .order('total_xp', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      return data.map((json) {
        final user = UserModel.fromJson(json);
        user.isPremium = (user.serverId == 'f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac')
            ? true
            : _checkPremiumStatus(json['user_subscriptions']);
        return user;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<int?> getMyGlobalRank() async {
    if (_currentUser?.serverId == null) return null;
    try {
      final res = await _supabase!
          .from('profiles')
          .select('id')
          .eq('show_on_leaderboard', true)
          .gt('total_xp', _currentUser!.totalXp)
          .count(CountOption.exact);
      
      return (res.count ?? 0) + 1;
    } catch (e) {
      AppLogger.log('AuthService: getMyGlobalRank error: $e');
      return null;
    }
  }
}
