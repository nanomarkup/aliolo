import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/services/auth_service.dart';

class FilterService extends ChangeNotifier {
  String _ageGroup = 'all';
  String _sourceFilter = 'all';

  String get ageGroup => _ageGroup;
  String get sourceFilter => _sourceFilter;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Default to 'all' or what was last saved locally
    _ageGroup = prefs.getString('last_age_filter') ?? 'all';
    _sourceFilter = prefs.getString('last_collection_filter') ?? 'all';

    // Override with user profile if available
    final user = getIt<AuthService>().currentUser;
    if (user != null) {
      _ageGroup = user.lastAgeGroup;
      _sourceFilter = user.lastSourceFilter;
    }
    
    notifyListeners();
  }

  Future<void> updateAgeGroup(String val) async {
    if (_ageGroup == val) return;
    _ageGroup = val;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_age_filter', val);

    final auth = getIt<AuthService>();
    if (auth.currentUser != null) {
      final user = auth.currentUser!;
      user.lastAgeGroup = val;
      await auth.updateUser(user);
    }
  }

  Future<void> updateSourceFilter(String val) async {
    if (_sourceFilter == val) return;
    _sourceFilter = val;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_collection_filter', val);

    final auth = getIt<AuthService>();
    if (auth.currentUser != null) {
      final user = auth.currentUser!;
      user.lastSourceFilter = val;
      await auth.updateUser(user);
    }
  }
}
