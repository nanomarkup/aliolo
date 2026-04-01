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
    final currentPrimaryColor = ThemeService().primaryColor;
    const appBarColor = Colors.white;
    final authService = getIt<AuthService>();

    return DefaultTabController(
      length: 3,
      child: AlioloPage(
        title: Text(
          context.t('documentation'),
          style: const TextStyle(color: appBarColor),
        ),
        appBarColor: currentPrimaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.school, color: appBarColor),
            onPressed:
                () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const SubjectPage()),
                  (route) => false,
                ),
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events, color: appBarColor),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LeaderboardPage()),
                ),
          ),
          IconButton(
            icon: ValueListenableBuilder<bool>(
              valueListenable: getIt<FeedbackService>().pendingNotifications,
              builder: (context, hasNotif, _) {
                return Badge(
                  isLabelVisible: hasNotif,
                  backgroundColor: Colors.amber,
                  child: const Icon(Icons.person, color: appBarColor),
                );
              },
            ),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                ),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: appBarColor),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                ),
          ),
          if (authService.currentUser?.showDocumentation ?? true)
            IconButton(
              icon: const Icon(Icons.help_outline, color: appBarColor),
              onPressed: () {},
            ),
        ],
        body: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: currentPrimaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: currentPrimaryColor,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: context.t('doc_tab_general')),
                Tab(text: context.t('doc_tab_learning')),
                Tab(text: context.t('doc_tab_creator')),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildTabContent([
                    _Section(context.t('doc_welcome_title'), context.t('doc_welcome_desc')),
                    _Section(context.t('doc_pillars_title'), context.t('doc_pillars_desc'), icon: Icons.category),
                    _Section(context.t('doc_leaderboard_title'), context.t('doc_leaderboard_desc'), icon: Icons.emoji_events),
                    _Section(context.t('doc_friends_title'), context.t('doc_friends_desc'), icon: Icons.group),
                    _Section(context.t('doc_streaks_title'), context.t('doc_streaks_desc'), icon: Icons.local_fire_department),
                    _Section(context.t('doc_goals_title'), context.t('doc_goals_desc'), icon: Icons.track_changes),
                    _Section(context.t('doc_public_title'), context.t('doc_public_desc'), icon: Icons.public),
                    _Section(context.t('doc_sync_title'), context.t('doc_sync_desc'), icon: Icons.cloud_sync),
                    _Section(context.t('doc_feedback_title'), context.t('doc_feedback_desc'), icon: Icons.feedback),
                  ], currentPrimaryColor),
                  _buildTabContent([
                    _Section(context.t('doc_lang_title'), context.t('doc_lang_desc'), icon: Icons.language),
                    _Section(context.t('doc_filters_title'), context.t('doc_filters_desc'), icon: Icons.tune),
                    _Section(context.t('doc_flashcards_title'), context.t('doc_flashcards_desc'), icon: Icons.style),
                    _Section(context.t('doc_study_modes_title'), context.t('doc_study_modes_desc'), icon: Icons.auto_awesome),
                    _Section(context.t('doc_testing_title'), context.t('doc_testing_desc'), icon: Icons.quiz),
                    _Section(context.t('doc_autoplay_title'), context.t('doc_autoplay_desc'), icon: Icons.play_circle_outline),
                    _Section(context.t('doc_math_title'), context.t('doc_math_desc'), icon: Icons.functions),
                  ], currentPrimaryColor),
                  _buildTabContent([
                    _Section(context.t('doc_organization_title'), context.t('doc_organization_desc'), icon: Icons.folder),
                    _Section(context.t('doc_creation_title'), context.t('doc_creation_desc'), icon: Icons.add_circle_outline),
                    _Section(context.t('doc_collections_purpose_title'), context.t('doc_collections_purpose_desc'), icon: Icons.auto_awesome_motion),
                    _Section(context.t('doc_card_scope_title'), context.t('doc_card_scope_desc'), icon: Icons.inventory_2),
                    _Section(context.t('doc_localization_ui_title'), context.t('doc_localization_ui_desc'), icon: Icons.ads_click),
                    _Section(context.t('doc_localization_details_title'), context.t('doc_localization_details_desc'), icon: Icons.translate),
                    _Section(context.t('doc_json_title'), context.t('doc_json_desc'), icon: Icons.code),
                    _Section(context.t('doc_media_title'), context.t('doc_media_desc'), icon: Icons.perm_media),
                  ], currentPrimaryColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(List<_Section> sections, Color color) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sections.map((s) => _buildSection(s.title, s.desc, color, s.icon)).toList(),
      ),
    );
  }

  Widget _buildSection(String title, String desc, Color color, IconData? icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
        Text(
          desc,
          style: const TextStyle(
            fontSize: 16,
            height: 1.5,
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
