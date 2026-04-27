import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AlioloLegalLinks {
  static final Uri privacy = Uri.parse('https://aliolo.com/privacy');
  static final Uri terms = Uri.parse('https://aliolo.com/terms');
  static final Uri refund = Uri.parse('https://aliolo.com/refund');
  static final Uri pricing = Uri.parse('https://aliolo.com/pricing');

  static Future<void> open(
    BuildContext context,
    Uri uri, {
    String? failureMessage,
  }) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failureMessage ?? 'Could not open ${uri.toString()}',
          ),
        ),
      );
    }
  }
}
