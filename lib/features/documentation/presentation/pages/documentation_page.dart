import 'package:flutter/material.dart';
import 'package:aliolo/core/widgets/aliolo_page.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/feedback_service.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';
import 'package:aliolo/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:aliolo/features/auth/presentation/pages/profile_page.dart';
import 'package:aliolo/features/settings/presentation/pages/settings_page.dart';

class DocumentationPage extends StatelessWidget {
  const DocumentationPage({super.key});

  @override
  Widget build(BuildContext context) {
    const appBarColor = Colors.white;
    final authService = getIt<AuthService>();

    return ListenableBuilder(
      listenable: Listenable.merge([TranslationService(), authService]),
      builder: (context, _) {
        final currentPrimaryColor = ThemeService().primaryColor;
        final isSmallScreen = MediaQuery.of(context).size.width < 600;

        final homeAction = IconButton(
          tooltip: context.t('home'),
          icon: const Icon(Icons.school),
          onPressed:
              () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const SubjectPage()),
                (route) => false,
              ),
        );
        final leaderboardAction = IconButton(
          tooltip: context.t('leaderboard'),
          icon: const Icon(Icons.emoji_events),
          onPressed:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LeaderboardPage(),
                ),
              ),
        );
        final profileAction = IconButton(
          tooltip: context.t('profile'),
          icon: ValueListenableBuilder<bool>(
            valueListenable: getIt<FeedbackService>().pendingNotifications,
            builder: (context, hasNotif, _) {
              return Badge(
                isLabelVisible: hasNotif,
                backgroundColor: Colors.amber,
                child: const Icon(Icons.person),
              );
            },
          ),
          onPressed:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              ),
        );
        final settingsAction = IconButton(
          tooltip: context.t('settings'),
          icon: const Icon(Icons.settings),
          onPressed:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              ),
        );
        final docAction = IconButton(
          tooltip: context.t('documentation'),
          icon: const Icon(Icons.help_outline),
          onPressed:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DocumentationPage()),
              ),
        );

        final gettingStartedSections = [
          _Section(
            context.t('doc_start_quick_title'),
            context.t('doc_start_quick_desc'),
            icon: Icons.play_circle_outline,
          ),
          _Section(
            context.t('doc_pillars_title'),
            context.t('doc_pillars_desc'),
            icon: Icons.category,
          ),
          _Section(
            context.t('doc_start_dashboard_title'),
            context.t('doc_start_dashboard_desc'),
            icon: Icons.tune,
          ),
          _Section(
            context.t('doc_start_structure_title'),
            context.t('doc_start_structure_desc'),
            icon: Icons.folder_copy_outlined,
          ),
          _Section(
            context.t('doc_leaderboard_title'),
            context.t('doc_leaderboard_desc'),
            icon: Icons.emoji_events,
          ),
          _Section(
            context.t('doc_friends_title'),
            context.t('doc_friends_desc'),
            icon: Icons.group,
          ),
          _Section(
            context.t('doc_start_progress_title'),
            context.t('doc_start_progress_desc'),
            icon: Icons.track_changes,
          ),
          _Section(
            context.t('doc_start_feedback_title'),
            context.t('doc_start_feedback_desc'),
            icon: Icons.feedback,
          ),
        ];

        final studySections = [
          _Section(
            context.t('doc_study_how_title'),
            context.t('doc_study_how_desc'),
            icon: Icons.auto_awesome,
          ),
          _Section(
            context.t('doc_lang_title'),
            context.t('doc_lang_desc'),
            icon: Icons.language,
          ),
          _Section(
            context.t('doc_study_modes_title'),
            context.t('doc_study_modes_desc'),
            icon: Icons.quiz,
          ),
          _Section(
            context.t('doc_flashcards_title'),
            context.t('doc_flashcards_desc'),
            icon: Icons.style,
          ),
          _Section(
            context.t('doc_study_scope_title'),
            context.t('doc_study_scope_desc'),
            icon: Icons.collections_bookmark_outlined,
          ),
          _Section(
            context.t('doc_study_media_title'),
            context.t('doc_study_media_desc'),
            icon: Icons.volume_up_outlined,
          ),
          _Section(
            context.t('doc_math_title'),
            context.t('doc_math_desc'),
            icon: Icons.functions,
          ),
        ];

        final creatorSections = [
          _Section(
            context.t('doc_create_model_title'),
            context.t('doc_create_model_desc'),
            icon: Icons.account_tree_outlined,
          ),
          _Section(
            context.t('doc_organization_title'),
            context.t('doc_organization_desc'),
            icon: Icons.folder,
          ),
          _Section(
            context.t('doc_creation_title'),
            context.t('doc_creation_desc'),
            icon: Icons.add_circle_outline,
          ),
          _Section(
            context.t('doc_create_visibility_title'),
            context.t('doc_create_visibility_desc'),
            icon: Icons.public,
          ),
          _Section(
            context.t('doc_collections_purpose_title'),
            context.t('doc_collections_purpose_desc'),
            icon: Icons.auto_awesome_motion,
          ),
          _Section(
            context.t('doc_create_localization_title'),
            context.t('doc_create_localization_desc'),
            icon: Icons.translate,
          ),
          _Section(
            context.t('doc_create_media_title'),
            context.t('doc_create_media_desc'),
            icon: Icons.perm_media,
          ),
          _Section(
            context.t('doc_create_json_title'),
            context.t('doc_create_json_desc'),
            icon: Icons.code,
          ),
        ];

        return DefaultTabController(
          length: 3,
          child: AlioloPage(
            title: Text(
              context.t('documentation'),
              style: const TextStyle(
                color: appBarColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            appBarColor: currentPrimaryColor,
            actions:
                isSmallScreen
                    ? [homeAction, profileAction, docAction]
                    : [
                      homeAction,
                      leaderboardAction,
                      profileAction,
                      settingsAction,
                      docAction,
                    ],
            overflowActions:
                isSmallScreen ? [leaderboardAction, settingsAction] : null,
            body: Column(
              children: [
                const SizedBox(height: 14),
                TabBar(
                  tabAlignment: TabAlignment.fill,
                  labelStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.normal,
                  ),
                  labelColor: currentPrimaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: currentPrimaryColor,
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(text: context.t('doc_tab_start')),
                    Tab(text: context.t('doc_tab_study')),
                    Tab(text: context.t('doc_tab_create')),
                  ],
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildTabContent(
                        context: context,
                        summary: context.t('doc_start_intro_desc'),
                        sections: gettingStartedSections,
                        color: currentPrimaryColor,
                      ),
                      _buildTabContent(
                        context: context,
                        summary: context.t('doc_study_intro_desc'),
                        sections: studySections,
                        color: currentPrimaryColor,
                      ),
                      _buildTabContent(
                        context: context,
                        summary: context.t('doc_create_intro_desc'),
                        sections: creatorSections,
                        color: currentPrimaryColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabContent({
    required BuildContext context,
    required String summary,
    required List<_Section> sections,
    required Color color,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary,
            style: TextStyle(
              fontSize: 15,
              height: 1.55,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 20),
          ...sections.asMap().entries.expand(
            (entry) => [
              if (entry.key != 0) const SizedBox(height: 18),
              _buildTabItemRow(context, entry.value, color),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabItemRow(BuildContext context, _Section section, Color color) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section.icon != null) ...[
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(section.icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                section.desc,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: bodyColor?.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section {
  final String title;
  final String desc;
  final IconData? icon;
  _Section(this.title, this.desc, {this.icon});
}
