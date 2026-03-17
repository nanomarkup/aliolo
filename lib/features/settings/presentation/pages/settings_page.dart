import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
import 'package:window_manager/window_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';
import 'package:aliolo/features/auth/presentation/pages/profile_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _authService = getIt<AuthService>();
  late bool _sidebarLeft;
  late String _themeMode;
  late bool _soundEnabled;
  late bool _showOnLeaderboard;
  late String _defaultLanguage;

  String _version = '1.0.0';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      windowManager.setResizable(true);
    }
    final user = _authService.currentUser;
    _sidebarLeft = user?.sidebarLeft ?? false;
    _themeMode = user?.themeMode ?? 'system';
    _soundEnabled = user?.soundEnabled ?? true;
    _showOnLeaderboard = user?.showOnLeaderboard ?? true;
    _defaultLanguage = user?.defaultLanguage ?? 'EN';
    _loadPackageInfo();

    if (pillars.isEmpty) {
      getIt<CardService>().getPillars().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = info.version;
    });
  }

  Future<void> _toggleSidebar(bool val) async {
    await _authService.updateSidebarPreference(val);
    setState(() => _sidebarLeft = val);
    _showSavedMsg();
  }

  Future<void> _updateTheme(String mode) async {
    await _authService.updateThemePreference(mode);
    ThemeService().setThemeFromString(mode);
    setState(() => _themeMode = mode);
    _showSavedMsg();
  }

  Future<void> _toggleSound(bool val) async {
    await _authService.updateSoundPreference(val);
    setState(() => _soundEnabled = val);
    _showSavedMsg();
  }

  Future<void> _toggleLeaderboard(bool val) async {
    await _authService.updateLeaderboardPreference(val);
    setState(() => _showOnLeaderboard = val);
    _showSavedMsg();
  }

  Future<void> _updateDefaultLanguage(String lang) async {
    await _authService.updateDefaultLanguage(lang);
    setState(() => _defaultLanguage = lang);
    _showSavedMsg();
  }

  void _showSavedMsg() {
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('setting_saved')),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12, top: 16),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const appBarColor = Colors.white;

    return ListenableBuilder(
      listenable: Listenable.merge([TranslationService(), ThemeService()]),
      builder: (context, _) {
        final currentPrimaryColor = ThemeService().primaryColor;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return AlioloScrollablePage(
          title: Text(
            context.t('settings'),
            style: const TextStyle(color: appBarColor),
          ),
          appBarColor: currentPrimaryColor,
          actions: [
            IconButton(
              icon: const Icon(Icons.school, color: appBarColor),
              onPressed:
                  () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SubjectPage(),
                    ),
                    (route) => false,
                  ),
            ),
            IconButton(
              icon: const Icon(Icons.emoji_events, color: appBarColor),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LeaderboardPage(),
                    ),
                  ),
            ),
            IconButton(
              icon: const Icon(Icons.person, color: appBarColor),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfilePage(),
                    ),
                  ),
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: appBarColor),
              onPressed: () => setState(() {}),
            ),
          ],
          body: Column(
            children: [
              _buildSectionTitle(
                context.t('general_preferences'),
                currentPrimaryColor,
              ),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(context.t('sidebar_left')),
                      subtitle: Text(context.t('sidebar_left_desc')),
                      secondary: Icon(
                        Icons.vertical_split,
                        color: currentPrimaryColor,
                      ),
                      value: _sidebarLeft,
                      onChanged: _toggleSidebar,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: Text(context.t('sound_effects')),
                      subtitle: Text(context.t('sound_effects_desc')),
                      secondary: Icon(
                        Icons.volume_up,
                        color: currentPrimaryColor,
                      ),
                      value: _soundEnabled,
                      onChanged: _toggleSound,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: Text(context.t('public_profile')),
                      subtitle: Text(context.t('public_profile_desc')),
                      secondary: Icon(
                        Icons.emoji_events,
                        color: currentPrimaryColor,
                      ),
                      value: _showOnLeaderboard,
                      onChanged: _toggleLeaderboard,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: Text(context.t('ui_language')),
                      leading: Icon(
                        Icons.translate,
                        color: currentPrimaryColor,
                      ),
                      trailing: SizedBox(
                        width: 150,
                        child: DropdownButton<String>(
                          value:
                              TranslationService().currentLocale.languageCode,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items:
                              TranslationService().availableUILanguages
                                  .map(
                                    (code) => DropdownMenuItem(
                                      value: code.toLowerCase(),
                                      child: Text(
                                        TranslationService().getLanguageName(
                                          code,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              TranslationService().setLocale(Locale(val));
                              _showSavedMsg();
                            }
                          },
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isSmall = constraints.maxWidth < 500;

                        final segmentedButton = SegmentedButton<String>(
                          segments: [
                            ButtonSegment<String>(
                              value: 'light',
                              label:
                                  isSmall
                                      ? null
                                      : Text(context.t('theme_light')),
                              icon: const Icon(Icons.light_mode, size: 18),
                            ),
                            ButtonSegment<String>(
                              value: 'dark',
                              label:
                                  isSmall ? null : Text(context.t('theme_dark')),
                              icon: const Icon(Icons.dark_mode, size: 18),
                            ),
                            ButtonSegment<String>(
                              value: 'system',
                              label:
                                  isSmall
                                      ? null
                                      : Text(context.t('theme_system')),
                              icon: const Icon(
                                Icons.settings_brightness,
                                size: 18,
                              ),
                            ),
                          ],
                          selected: {_themeMode},
                          onSelectionChanged: (Set<String> newSelection) {
                            _updateTheme(newSelection.first);
                          },
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: currentPrimaryColor,
                            selectedForegroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                          showSelectedIcon: false,
                        );

                        if (isSmall) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                title: Text(context.t('theme_mode')),
                                leading: Icon(
                                  Icons.brightness_medium,
                                  color: currentPrimaryColor,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: segmentedButton,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          );
                        }

                        return ListTile(
                          title: Text(context.t('theme_mode')),
                          leading: Icon(
                            Icons.brightness_medium,
                            color: currentPrimaryColor,
                          ),
                          trailing: segmentedButton,
                        );
                      },
                    ),

                    const Divider(height: 1),
                    ListTile(
                      title: Text(context.t('theme_color')),
                      subtitle: Text(context.t('theme_color_desc')),
                      leading: Icon(Icons.palette, color: currentPrimaryColor),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children:
                            pillars.map((p) {
                              final color = p.getColor();
                              final isSelected =
                                  ThemeService.toHexStatic(color) ==
                                  ThemeService.toHexStatic(
                                    ThemeService().primaryColor,
                                  );

                              return GestureDetector(
                                onTap:
                                    () => _authService.updateMainColor(
                                      ThemeService.toHexStatic(color),
                                    ),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : Colors.transparent,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child:
                                      isSelected
                                          ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                          )
                                          : null,
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  '${context.t('version')} $_version',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ),
            ],
          ),
          slivers: const [],
        );
      },
    );
  }
}
