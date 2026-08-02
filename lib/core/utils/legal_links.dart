import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AlioloLegalLinks {
  static final Uri website = Uri.parse('https://aliolo.com');
  static final Uri privacy = Uri.parse('https://aliolo.com/privacy.html');
  static final Uri terms = Uri.parse('https://aliolo.com/terms.html');
  static final Uri refund = Uri.parse('https://aliolo.com/refund.html');
  static final Uri pricing = Uri.parse('https://aliolo.com/pricing.html');

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
