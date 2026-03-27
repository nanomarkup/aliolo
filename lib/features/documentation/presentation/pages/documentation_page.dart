import 'package:flutter/material.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/translation_service.dart';

class DocumentationPage extends StatelessWidget {
  const DocumentationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentPrimaryColor = ThemeService().primaryColor;
    const appBarColor = Colors.white;

    return AlioloScrollablePage(
      title: Text(
        context.t('documentation'),
        style: const TextStyle(color: appBarColor),
      ),
      appBarColor: currentPrimaryColor,
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: appBarColor),
          onPressed: () => Navigator.pop(context),
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
