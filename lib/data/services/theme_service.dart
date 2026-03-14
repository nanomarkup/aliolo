import 'package:flutter/material.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(
    ThemeMode.system,
  );

  static const Color orange = Colors.orange;
  static const Color mainColor = orange; // For backward compatibility

  // Dynamic primary color
  Color _primaryColor = orange;
  Color get primaryColor => _primaryColor;

  final ValueNotifier<Color> sessionColorNotifier = ValueNotifier(orange);

  void setTheme(ThemeMode mode) {
    themeNotifier.value = mode;
    notifyListeners();
  }

  void setPrimaryColor(Color color) {
    _primaryColor = color;
    sessionColorNotifier.value = color;
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

  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  static String toHexStatic(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  String toHex(Color color) => toHexStatic(color);
}
