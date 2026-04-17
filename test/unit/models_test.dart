import 'package:flutter_test/flutter_test.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/collection_model.dart';
import 'package:aliolo/data/models/feedback_model.dart';
import 'package:aliolo/data/models/feedback_reply_model.dart';
import 'package:aliolo/data/services/feedback_service.dart';

void main() {
  group('Model Boolean Parsing Tests', () {
    test(
      'SubjectModel correctly parses is_public and is_on_dashboard from int',
      () {
        final json = {
          'id': 'test_subj',
          'pillar_id': 1,
          'owner_id': 'user_1',
          'is_public': 1,
          'is_on_dashboard': 1,
          'localized_data': '{}',
          'created_at': '2026-04-13T12:00:00Z',
          'updated_at': '2026-04-13T12:00:00Z',
        };

        final model = SubjectModel.fromJson(json);
        expect(model.isPublic, isTrue);
        expect(model.isOnDashboard, isTrue);

        final json2 = Map<String, dynamic>.from(json);
        json2['is_public'] = 0;
        json2['is_on_dashboard'] = 0;

        final model2 = SubjectModel.fromJson(json2);
        expect(model2.isPublic, isFalse);
        expect(model2.isOnDashboard, isFalse);
      },
    );

    test('SubjectModel ignores visual_template and serializes without it', () {
      final json = {
        'id': 'test_subj_template',
        'pillar_id': 1,
        'owner_id': 'user_1',
        'is_public': 1,
        'name': 'Counting',
        'visual_template': 'counting',
        'localized_data': '{}',
        'created_at': '2026-04-13T12:00:00Z',
        'updated_at': '2026-04-13T12:00:00Z',
      };

      final model = SubjectModel.fromJson(json);
      expect(model.name, 'Counting');
      expect(model.toJson().containsKey('visual_template'), isFalse);
    });

    test(
      'CollectionModel correctly parses is_public and is_on_dashboard from int',
      () {
        final json = {
          'id': 'test_coll',
          'pillar_id': 1,
          'owner_id': 'user_1',
          'is_public': 1,
          'is_on_dashboard': 1,
          'localized_data': '{}',
          'created_at': '2026-04-13T12:00:00Z',
          'updated_at': '2026-04-13T12:00:00Z',
        };

        final model = CollectionModel.fromJson(json);
        expect(model.isPublic, isTrue);
        expect(model.isOnDashboard, isTrue);
      },
    );

    test('CardModel correctly parses is_public from int', () {
      final json = {
        'id': 'test_card',
        'subject_id': 'subj_1',
        'owner_id': 'user_1',
        'is_public': 1,
        'localized_data': '{}',
        'created_at': '2026-04-13T12:00:00Z',
        'updated_at': '2026-04-13T12:00:00Z',
      };

      final model = CardModel.fromJson(json);
      expect(model.isPublic, isTrue);
    });

    test('CardModel reads renderer from json and supports counting', () {
      final json = {
        'id': 'test_card_math',
        'subject_id': 'subj_1',
        'owner_id': 'user_1',
        'renderer': 'counting',
        'display_text': '1 + 1',
        'display_texts': '{"es":"1 + 1"}',
        'localized_data': '{}',
        'created_at': '2026-04-13T12:00:00Z',
        'updated_at': '2026-04-13T12:00:00Z',
      };

      final model = CardModel.fromJson(json);
      expect(model.renderer, 'counting');
      expect(model.isCountingRenderer, isTrue);
      expect(model.displayText, '1 + 1');
      expect(model.getDisplayText('es'), '1 + 1');
      expect(model.toJson().containsKey('test_mode'), isFalse);
      expect(model.toJson()['display_text'], '1 + 1');
    });
  });

  group('Feedback media parsing and paths', () {
    test('FeedbackModel parses D1 JSON text fields', () {
      final model = FeedbackModel.fromJson({
        'id': 'feedback_1',
        'user_id': 'user_1',
        'type': 'bug',
        'title': 'Title',
        'content': 'Content',
        'attachment_urls':
            '["https://aliolo.com/storage/v1/object/public/aliolo-media/feedbacks/feedback_1/file.png"]',
        'metadata': '{"context":"Card details"}',
        'owner_name': 'User',
        'owner_email': 'user@example.com',
      });

      expect(model.attachmentUrls, hasLength(1));
      expect(model.attachmentUrls.first, contains('/feedbacks/feedback_1/'));
      expect(model.metadata['context'], 'Card details');
      expect(model.subjectName, 'Card details');
      expect(model.userName, 'User');
      expect(model.userEmail, 'user@example.com');
    });

    test('FeedbackReplyModel parses D1 JSON text attachment_urls', () {
      final model = FeedbackReplyModel.fromJson({
        'id': 'reply_1',
        'feedback_id': 'feedback_1',
        'user_id': 'user_1',
        'content': 'Reply',
        'attachment_urls':
            '["https://aliolo.com/storage/v1/object/public/aliolo-media/feedbacks/feedback_1/reply_1/file.png"]',
      });

      expect(model.attachmentUrls, hasLength(1));
      expect(
        model.attachmentUrls.first,
        contains('/feedbacks/feedback_1/reply_1/'),
      );
    });

    test('FeedbackService builds feedback and reply attachment paths', () {
      expect(
        FeedbackService.feedbackAttachmentPath('feedback_1', 'file.png'),
        'feedbacks/feedback_1/file.png',
      );
      expect(
        FeedbackService.replyAttachmentPath(
          'feedback_1',
          'reply_1',
          'file.png',
        ),
        'feedbacks/feedback_1/reply_1/file.png',
      );
    });
  });
}
