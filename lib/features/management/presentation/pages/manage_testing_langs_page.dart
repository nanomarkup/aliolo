import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aliolo/data/services/testing_language_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/core/widgets/resize_wrapper.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';
import 'package:aliolo/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:aliolo/features/auth/presentation/pages/profile_page.dart';
import 'package:aliolo/features/settings/presentation/pages/settings_page.dart';

class ManageTestingLangsPage extends StatefulWidget {
  const ManageTestingLangsPage({super.key});

  @override
  State<ManageTestingLangsPage> createState() => _ManageTestingLangsPageState();
}

class _ManageTestingLangsPageState extends State<ManageTestingLangsPage> {
  final _langService = TestingLanguageService();

  @override
  Widget build(BuildContext context) {
    const appBarColor = Colors.white;
    const Color currentSessionColor = ThemeService.mainColor;

    return ListenableBuilder(
      listenable: Listenable.merge([TranslationService(), _langService]),
      builder: (context, _) {
        return ResizeWrapper(
          child: Scaffold(
            appBar: AppBar(
              title: DragToMoveArea(
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    context.t('manage_testing_langs'),
                    style: const TextStyle(color: appBarColor),
                  ),
                ),
              ),
              backgroundColor: currentSessionColor,
              foregroundColor: appBarColor,
              automaticallyImplyLeading: false,
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
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsPage(),
                        ),
                      ),
                ),
                const WindowControls(color: appBarColor, iconSize: 24),
              ],
            ),
            body: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 700),
                padding: const EdgeInsets.all(24),
                child: ListView.builder(
                  itemCount: _langService.allLanguages.length,
                  itemBuilder: (context, index) {
                    final lang = _langService.allLanguages[index];
                    final isActive = _langService.activeLanguageCodes.contains(
                      lang.code,
                    );
                    return SwitchListTile(
                      title: Text(lang.nativeName),
                      subtitle: Text(lang.name),
                      value: isActive,
                      onChanged: (_) => _langService.toggleLanguage(lang.code),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
