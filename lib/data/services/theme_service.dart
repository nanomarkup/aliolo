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

  // Semantic Colors based on current theme mode
  Color get success => isDarkMode ? const Color(0xFF81C784) : const Color(0xFF4CAF50);
  Color get error => isDarkMode ? const Color(0xFFEF5350) : const Color(0xFFF44336);
  Color get streak => error;
  Color get xp => isDarkMode ? const Color(0xFFE68A00) : const Color(0xFFFF9800);
  Color get amber => const Color(0xFFFFC107);
  Color get hint => isDarkMode ? const Color(0xFFA0A0A0) : const Color(0xFF888888);

  /// Returns the primary color adjusted for the current theme mode
  Color getAdjustedPrimary([Color? baseColor]) {
    final color = baseColor ?? _primaryColor;
    if (!isDarkMode) return color;
    
    // For dark mode, if it's the default orange, use the requested #E68A00
    if (color.value == orange.value) return const Color(0xFFE68A00);
    
    // For other custom colors, slightly darken/desaturate for dark mode comfort
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - 0.05).clamp(0.0, 1.0)).toColor();
  }

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
