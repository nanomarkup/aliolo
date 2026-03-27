import 'package:flutter/material.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
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

    return AlioloScrollablePage(
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context.t('doc_welcome_title'), currentPrimaryColor),
            _buildText(context.t('doc_welcome_desc')),
            
            _buildHeader(context.t('doc_flashcards_title'), currentPrimaryColor),
            _buildText(context.t('doc_flashcards_desc')),
            
            _buildHeader(context.t('doc_testing_title'), currentPrimaryColor),
            _buildText(context.t('doc_testing_desc')),
            
            _buildHeader(context.t('doc_streaks_title'), currentPrimaryColor),
            _buildText(context.t('doc_streaks_desc')),
            
            _buildHeader(context.t('doc_goals_title'), currentPrimaryColor),
            _buildText(context.t('doc_goals_desc')),
            
            _buildHeader(context.t('doc_sync_title'), currentPrimaryColor),
            _buildText(context.t('doc_sync_desc')),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
      slivers: const [],
    );
  }

  Widget _buildHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        height: 1.5,
      ),
    );
  }
}
