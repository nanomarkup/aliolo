import 'package:flutter/material.dart';
import 'package:aliolo/data/models/pillar_model.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(
    ThemeMode.system,
  );

  static const Color orange = Colors.orange;
  static const Color mainColor = orange; // For backward compatibility
  
  // The fixed brand orange for non-working pages
  static const Color alioloOrange = orange;

  // Pillar 6 (Academic & Professional) colors for system pages
  Color getSystemColor([Brightness? brightness]) {
    final dark = resolveIsDarkMode(brightness);
    return dark ? const Color(0xFF3F51B5) : const Color(0xFF1D4289);
  }

  // Dynamic primary color
  Color _primaryColor = orange;
  int _currentPillarId = 8;
  Color get primaryColor => _primaryColor;

  // Semantic Colors based on current theme mode
  Color getSuccess([Brightness? brightness]) => resolveIsDarkMode(brightness) ? const Color(0xFF81C784) : const Color(0xFF4CAF50);
  Color getError([Brightness? brightness]) => resolveIsDarkMode(brightness) ? const Color(0xFFEF5350) : const Color(0xFFF44336);
  Color getStreak([Brightness? brightness]) => getError(brightness);
  Color getXp([Brightness? brightness]) => resolveIsDarkMode(brightness) ? const Color(0xFFE68A00) : const Color(0xFFFF9800);
  Color getAmber() => const Color(0xFFFFC107);
  Color getHint([Brightness? brightness]) => resolveIsDarkMode(brightness) ? const Color(0xFFA0A0A0) : const Color(0xFF888888);

  // Backward compatibility getters (using default system brightness if not specified)
  Color get success => getSuccess();
  Color get error => getError();
  Color get streak => getStreak();
  Color get xp => getXp();
  Color get amber => getAmber();
  Color get hint => getHint();
  Color get systemColor => getSystemColor();

  /// Returns the primary color adjusted for the current theme mode
  /// Set [forceOrange] to true for non-working pages (Login, About, etc.)
  Color getAdjustedPrimary({Color? baseColor, bool forceOrange = false, Brightness? brightness}) {
    final color = forceOrange ? alioloOrange : (baseColor ?? _primaryColor);
    if (!resolveIsDarkMode(brightness)) return color;
    
    // For dark mode, if it's the brand orange, use the requested #E68A00
    if (color.value == orange.value) return const Color(0xFFE68A00);
    
    // For other custom colors, slightly darken/desaturate for dark mode comfort
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - 0.05).clamp(0.0, 1.0)).toColor();
  }

  final ValueNotifier<Color> sessionColorNotifier = ValueNotifier(orange);

  void setPrimaryColorFromPillar(int pillarId, [Brightness? brightness]) {
    _currentPillarId = pillarId;
    _refreshPrimaryColor(brightness);
  }

  void _refreshPrimaryColor([Brightness? brightness]) {
    // Find the pillar in the global list
    final pillar = pillars.firstWhere(
      (p) => p.id == _currentPillarId,
      orElse:
          () => pillars.firstWhere(
            (p) => p.id == 8,
            orElse:
                () =>
                    pillars.isNotEmpty
                        ? pillars.first
                        : Pillar(id: 8, icon: '', lightColor: '#FF9800'),
          ),
    );

    // Set primary based on the pillar's theme-aware color
    _primaryColor = pillar.getColor(resolveIsDarkMode(brightness));
    notifyListeners();
  }

  void setTheme(ThemeMode mode) {
    themeNotifier.value = mode;
    _refreshPrimaryColor();
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
    _refreshPrimaryColor();
  }

  bool resolveIsDarkMode([Brightness? brightness]) {
    if (themeNotifier.value == ThemeMode.dark) return true;
    if (themeNotifier.value == ThemeMode.light) return false;
    // If system, use provided brightness or fallback to platform
    if (brightness != null) return brightness == Brightness.dark;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }

  bool get isDarkMode => resolveIsDarkMode();

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
