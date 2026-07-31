import 'package:flutter_test/flutter_test.dart';
import 'package:aliolo/data/models/onboarding_analytics_model.dart';

void main() {
  group('OnboardingAnalyticsPageModel', () {
    test('parses summary, breakdowns, and recent sessions', () {
      final model = OnboardingAnalyticsPageModel.fromJson({
        'summary': {
          'total_sessions': 3,
          'linked_email_sessions': 2,
          'age_selected_sessions': 2,
          'pillar_selected_sessions': 2,
          'final_slide_sessions': 1,
          'unique_emails': 2,
          'average_last_slide_index': 4.5,
          'completion_rate': 0.33,
          'final_slide_index': 6,
          'latest_updated_at': '2026-04-25T10:00:00Z',
        },
        'age_breakdown': [
          {'age_range': 'age_15_18', 'sessions': 2},
        ],
        'pillar_breakdown': [
          {
            'pillar_id': 6,
            'pillar_name': 'Academic & Professional',
            'sessions': 2,
          },
        ],
        'slide_breakdown': [
          {'last_slide_index': 6, 'sessions': 1},
        ],
        'recent_sessions': [
          {
            'session_id': 'oa-session-1',
            'user_email': 'user@example.com',
            'age_range': 'age_15_18',
            'pillar_id': 6,
            'pillar_name': 'Academic & Professional',
            'last_slide_index': 6,
            'created_at': '2026-04-25T09:00:00Z',
            'updated_at': '2026-04-25T10:00:00Z',
          },
        ],
      });

      expect(model.summary.totalSessions, 3);
      expect(model.summary.uniqueEmails, 2);
      expect(model.summary.averageLastSlideIndex, 4.5);
      expect(model.ageBreakdown.first.ageRange, 'age_15_18');
      expect(model.pillarBreakdown.first.pillarId, 6);
      expect(model.recentSessions.first.sessionId, 'oa-session-1');
      expect(model.recentSessions.first.pillarName, 'Academic & Professional');
    });
  });
}
