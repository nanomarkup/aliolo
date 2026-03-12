import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aliolo/core/widgets/floating_app_bar.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/learning_language_service.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/core/widgets/resize_wrapper.dart';

import 'package:aliolo/features/settings/presentation/pages/about_page.dart';
import 'package:aliolo/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:aliolo/features/management/presentation/pages/manage_cards_page.dart';
import 'package:aliolo/features/auth/presentation/pages/profile_page.dart';
import 'package:aliolo/features/management/presentation/pages/user_management_page.dart';

import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _authService = AuthService();
  final _cardService = CardService();
  late bool _sidebarLeft;
  late String _themeMode;
  late bool _soundEnabled;
  late bool _showOnLeaderboard;
  late int _shortcutPrev;
  late int _shortcutNext;
  late String _defaultLanguage;
  List<String> _availableLanguages = ['EN'];

  String _version = '1.0.0';

  @override
  void initState() {
    super.initState();
    windowManager.setResizable(true);
    final user = _authService.currentUser;
    _sidebarLeft = user?.sidebarLeft ?? false;
    _themeMode = user?.themeMode ?? 'system';
    _soundEnabled = user?.soundEnabled ?? true;
    _showOnLeaderboard = user?.showOnLeaderboard ?? true;
    _shortcutPrev = user?.shortcutPrevKey ?? 0x0000000042b;
    _shortcutNext = user?.shortcutNextKey ?? 0x0000000042a;
    _defaultLanguage = user?.defaultLanguage ?? 'EN';
    _loadPackageInfo();
    _loadLanguages();
  }

  Future<void> _loadLanguages() async {
    final langs = await _cardService.getAvailableLanguages();
    if (mounted) {
      setState(() {
        _availableLanguages = langs;
        if (!_availableLanguages.contains(_defaultLanguage)) {
          _defaultLanguage = 'EN';
        }
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

  Future<void> _listenForKey(bool isPrev) async {
    final key = await showDialog<LogicalKeyboardKey>(
      context: context,
      builder: (context) => _KeyCaptureDialog(),
    );

    if (key != null) {
      int prev = isPrev ? key.keyId : _shortcutPrev;
      int next = isPrev ? _shortcutNext : key.keyId;

      await _authService.updateShortcuts(prev, next);
      setState(() {
        _shortcutPrev = prev;
        _shortcutNext = next;
      });
      _showSavedMsg();
    }
  }

  String _getKeyName(BuildContext context, int id) {
    if (id == 0x0000000042b) return context.t('left_arrow');
    if (id == 0x0000000042a) return context.t('right_arrow');
    if (id == 0x00000000429) return context.t('up_arrow');
    if (id == 0x00000000428) return context.t('down_arrow');
    try {
      final key = LogicalKeyboardKey.findKeyByKeyId(id);
      return key?.keyLabel ?? "Key $id";
    } catch (_) {
      return "Key $id";
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
    const Color currentSessionColor = ThemeService.mainColor;

    return ListenableBuilder(
      listenable: TranslationService(),
      builder: (context, _) {
        return ResizeWrapper(
          child: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AlioloAppBar(
              title: Text(
                context.t('settings'),
                style: const TextStyle(color: appBarColor),
              ),
              backgroundColor: currentSessionColor,
              foregroundColor: appBarColor,
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
                  icon: const Icon(
                    Icons.collections_bookmark,
                    color: appBarColor,
                  ),
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManageCardsPage(),
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
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 80),
                      Expanded(
                        child: ListView(
                          children: [
                            _buildSectionTitle(
                              context.t('general_preferences'),
                              currentSessionColor,
                            ),
                            Card(
                              child: Column(
                                children: [
                                  SwitchListTile(
                                    title: Text(context.t('sidebar_left')),
                                    subtitle: Text(
                                      context.t('sidebar_left_desc'),
                                    ),
                                    secondary: Icon(
                                      Icons.vertical_split,
                                      color: currentSessionColor,
                                    ),
                                    value: _sidebarLeft,
                                    onChanged: _toggleSidebar,
                                  ),
                                  const Divider(height: 1),
                                  SwitchListTile(
                                    title: Text(context.t('sound_effects')),
                                    subtitle: Text(
                                      context.t('sound_effects_desc'),
                                    ),
                                    secondary: Icon(
                                      Icons.volume_up,
                                      color: currentSessionColor,
                                    ),
                                    value: _soundEnabled,
                                    onChanged: _toggleSound,
                                  ),
                                  const Divider(height: 1),
                                  SwitchListTile(
                                    title: Text(context.t('public_profile')),
                                    subtitle: Text(
                                      context.t('public_profile_desc'),
                                    ),
                                    secondary: Icon(
                                      Icons.emoji_events,
                                      color: currentSessionColor,
                                    ),
                                    value: _showOnLeaderboard,
                                    onChanged: _toggleLeaderboard,
                                  ),
                                  const Divider(height: 1),
                                  ListTile(
                                    title: Text(context.t('ui_language')),
                                    leading: Icon(
                                      Icons.translate,
                                      color: currentSessionColor,
                                    ),
                                    trailing: SizedBox(
                                      width: 150,
                                      child: DropdownButton<String>(
                                        value:
                                            TranslationService()
                                                .currentLocale
                                                .languageCode,
                                        underline: const SizedBox(),
                                        isExpanded: true,
                                        alignment:
                                            AlignmentDirectional.centerEnd,
                                        items:
                                            TranslationService()
                                                .availableUILanguages
                                                .map(
                                                  (code) => DropdownMenuItem(
                                                    value: code,
                                                    alignment:
                                                        AlignmentDirectional
                                                            .centerEnd,
                                                    child: Text(
                                                      TranslationService()
                                                          .getLanguageName(
                                                            code,
                                                          ),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            TranslationService().setLocale(
                                              Locale(val),
                                            );
                                            _authService
                                                .updateUiLanguagePreference(
                                                  val,
                                                );
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  ListTile(
                                    title: Text(
                                      context.t('default_learning_language'),
                                    ),
                                    subtitle: Text(
                                      context.t(
                                        'default_learning_language_desc',
                                      ),
                                    ),
                                    leading: Icon(
                                      Icons.language,
                                      color: currentSessionColor,
                                    ),
                                    trailing: SizedBox(
                                      width: 150,
                                      child: ListenableBuilder(
                                        listenable: LearningLanguageService(),
                                        builder: (context, _) {
                                          final rawActiveLangs =
                                              LearningLanguageService()
                                                  .activeLanguageCodes
                                                  .map((c) => c.toLowerCase())
                                                  .toSet();
                                          if (!rawActiveLangs.contains(
                                            _defaultLanguage.toLowerCase(),
                                          )) {
                                            rawActiveLangs.add(
                                              _defaultLanguage.toLowerCase(),
                                            );
                                          }
                                          final activeLangs =
                                              rawActiveLangs.toList()..sort();

                                          return DropdownButton<String>(
                                            value:
                                                _defaultLanguage.toLowerCase(),
                                            underline: const SizedBox(),
                                            isExpanded: true,
                                            alignment:
                                                AlignmentDirectional.centerEnd,
                                            items:
                                                activeLangs
                                                    .map(
                                                      (l) => DropdownMenuItem(
                                                        value: l,
                                                        alignment:
                                                            AlignmentDirectional
                                                                .centerEnd,
                                                        child: Text(
                                                          LearningLanguageService()
                                                              .getLanguageName(
                                                                l,
                                                              ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                            onChanged: (val) {
                                              if (val != null)
                                                _updateDefaultLanguage(val);
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.brightness_medium,
                                              color: currentSessionColor,
                                            ),
                                            const SizedBox(width: 16),
                                            Text(
                                              context.t('theme_mode'),
                                              style: const TextStyle(
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Center(
                                          child: SegmentedButton<String>(
                                            segments: [
                                              ButtonSegment(
                                                value: 'system',
                                                label: Text(
                                                  context.t('system'),
                                                ),
                                                icon: const Icon(
                                                  Icons.brightness_auto,
                                                ),
                                              ),
                                              ButtonSegment(
                                                value: 'light',
                                                label: Text(context.t('light')),
                                                icon: const Icon(
                                                  Icons.light_mode,
                                                ),
                                              ),
                                              ButtonSegment(
                                                value: 'dark',
                                                label: Text(context.t('dark')),
                                                icon: const Icon(
                                                  Icons.dark_mode,
                                                ),
                                              ),
                                            ],
                                            selected: {_themeMode},
                                            onSelectionChanged: (
                                              Set<String> newSelection,
                                            ) {
                                              _updateTheme(newSelection.first);
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            _buildSectionTitle(
                              context.t('keyboard_shortcuts'),
                              currentSessionColor,
                            ),
                            Card(
                              child: Column(
                                children: [
                                  ListTile(
                                    title: Text(context.t('previous_card')),
                                    subtitle: Text(
                                      "Ctrl + ${_getKeyName(context, _shortcutPrev)}",
                                    ),
                                    leading: Icon(
                                      Icons.keyboard,
                                      color: currentSessionColor,
                                    ),
                                    trailing: const Icon(Icons.edit, size: 18),
                                    onTap: () => _listenForKey(true),
                                  ),
                                  const Divider(height: 1),
                                  ListTile(
                                    title: Text(context.t('next_card')),
                                    subtitle: Text(
                                      "Ctrl + ${_getKeyName(context, _shortcutNext)}",
                                    ),
                                    leading: Icon(
                                      Icons.keyboard,
                                      color: currentSessionColor,
                                    ),
                                    trailing: const Icon(Icons.edit, size: 18),
                                    onTap: () => _listenForKey(false),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Text(
                              'Aliolo Pro',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: currentSessionColor.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${context.t('version')} $_version',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KeyCaptureDialog extends StatefulWidget {
  @override
  State<_KeyCaptureDialog> createState() => _KeyCaptureDialogState();
}

class _KeyCaptureDialogState extends State<_KeyCaptureDialog> {
  final FocusNode _node = FocusNode();

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _node,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.controlLeft ||
              event.logicalKey == LogicalKeyboardKey.controlRight ||
              event.logicalKey == LogicalKeyboardKey.shiftLeft ||
              event.logicalKey == LogicalKeyboardKey.shiftRight ||
              event.logicalKey == LogicalKeyboardKey.altLeft ||
              event.logicalKey == LogicalKeyboardKey.altRight) {
            return;
          }
          Navigator.pop(context, event.logicalKey);
        }
      },
      child: AlertDialog(
        title: Text(context.t('record_shortcut')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.keyboard, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(context.t('shortcuts_hint')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t('cancel')),
          ),
        ],
      ),
    );
  }
}
