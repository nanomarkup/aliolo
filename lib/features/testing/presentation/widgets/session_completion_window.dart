import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class SessionCompletionWindow extends StatelessWidget {
  final String subjectTitle;
  final Color headerColor;
  final Widget body;
  final VoidCallback onBackPressed;
  final String actionLabel;
  final IconData actionIcon;

  const SessionCompletionWindow({
    super.key,
    required this.subjectTitle,
    required this.headerColor,
    required this.body,
    required this.onBackPressed,
    this.actionLabel = 'Back to Subjects',
    this.actionIcon = Icons.school,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(subjectTitle, style: const TextStyle(fontSize: 18)),
        backgroundColor: headerColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: onBackPressed,
          ),
          if (!kIsWeb) const WindowControls(color: Colors.white),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.t('session_complete'),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 48),
                    body,
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: onBackPressed,
                        icon: Icon(actionIcon),
                        label: Text(
                          actionLabel,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: headerColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
