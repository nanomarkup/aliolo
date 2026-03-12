import 'package:flutter/material.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(
    ThemeMode.system,
  );
  static const Color mainColor = Colors.orange;
  final ValueNotifier<Color> sessionColorNotifier = ValueNotifier(mainColor);

  void setTheme(ThemeMode mode) {
    themeNotifier.value = mode;
    notifyListeners();
  }

  void setSessionColor(Color color) {
    sessionColorNotifier.value = color;
    notifyListeners();
  }

  void setThemeFromString(String mode) {
    switch (mode) {
      case 'dark':
        themeNotifier.value = ThemeMode.dark;
        break;
      case 'light':
        themeNotifier.value = ThemeMode.light;
        break;
      case 'system':
      default:
        themeNotifier.value = ThemeMode.system;
        break;
    }
    notifyListeners();
  }

  bool get isDarkMode => themeNotifier.value == ThemeMode.dark;
}
