import 'package:flutter_test/flutter_test.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/user_model.dart';
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

    test('SubjectModel derives type helpers from subject name', () {
      final json = {
        'id': 'test_subj_template',
        'pillar_id': 1,
        'owner_id': 'user_1',
        'is_public': 1,
        'name': 'Counting',
        'localized_data': '{}',
        'created_at': '2026-04-13T12:00:00Z',
        'updated_at': '2026-04-13T12:00:00Z',
      };

      final model = SubjectModel.fromJson(json);
      expect(model.name, 'Counting');
      expect(model.isCounting, isTrue);
      expect(model.isMath, isFalse);
    });

    test('SubjectModel maps addition and subtraction subjects', () {
      final additionSmallJson = {
        'id': 'de04da1c-9820-4e61-ae6b-bc7ed07eeb93',
        'pillar_id': 1,
        'owner_id': 'user_1',
        'is_public': 1,
        'name': 'Addition 0-10',
        'localized_data': '{}',
        'created_at': '2026-04-13T12:00:00Z',
        'updated_at': '2026-04-13T12:00:00Z',
      };

      final additionJson = {
        'id': '5e81da1f-f92c-44d2-b3cd-f921d05425df',
        'pillar_id': 1,
        'owner_id': 'user_1',
        'is_public': 1,
        'name': 'Addition 11-20',
        'localized_data': '{}',
        'created_at': '2026-04-13T12:00:00Z',
        'updated_at': '2026-04-13T12:00:00Z',
      };

      final subtractionJson = {
        'id': 'f59a0f9c-5d6d-4f2d-b426-eb9ca6bf2782',
        'pillar_id': 1,
        'owner_id': 'user_1',
        'is_public': 1,
        'name': 'Subtraction 11-20',
        'localized_data': '{}',
        'created_at': '2026-04-13T12:00:00Z',
        'updated_at': '2026-04-13T12:00:00Z',
      };

      final subtractionSmallJson = {
        'id': 'ce04da1c-9820-4e61-ae6b-bc7ed07eeb93',
        'pillar_id': 1,
        'owner_id': 'user_1',
        'is_public': 1,
        'name': 'Subtraction 0-10',
        'localized_data': '{}',
        'created_at': '2026-04-13T12:00:00Z',
        'updated_at': '2026-04-13T12:00:00Z',
      };

      final addition = SubjectModel.fromJson(additionJson);
      final additionSmall = SubjectModel.fromJson(additionSmallJson);
      final subtractionSmall = SubjectModel.fromJson(subtractionSmallJson);
      final subtraction = SubjectModel.fromJson(subtractionJson);

      expect(additionSmall.maxOperand, 10);
      expect(addition.isAddition, isTrue);
      expect(addition.isSubtraction, isFalse);
      expect(addition.maxOperand, 20);
      expect(subtractionSmall.maxOperand, 10);
      expect(subtraction.isSubtraction, isTrue);
      expect(subtraction.isAddition, isFalse);
      expect(subtraction.maxOperand, 20);
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

    test('CardModel reads renderer from json and supports special renderers', () {
      final json = {
        'id': 'test_card_math',
        'subject_id': 'subj_1',
        'owner_id': 'user_1',
        'renderer': 'addition_number',
        'display_text': '',
        'display_texts': '{"es":""}',
        'localized_data': '{}',
        'created_at': '2026-04-13T12:00:00Z',
        'updated_at': '2026-04-13T12:00:00Z',
      };

      final model = CardModel.fromJson(json);
      expect(model.renderer, 'addition_number');
      expect(model.isSpecialRenderer, isTrue);
      expect(model.isAdditionNumberRenderer, isTrue);
      expect(model.isCountingRenderer, isFalse);
      expect(model.isAdditionEmojiRenderer, isFalse);
      expect(model.toJson().containsKey('test_mode'), isFalse);
      expect(model.toJson()['renderer'], 'addition_number');
    });

    test('CardModel parses colors from display_text only', () {
      final json = {
        'id': 'color_card',
        'subject_id': 'subj_1',
        'owner_id': 'user_1',
        'renderer': 'colors',
        'answer': 'Sky Blue, #87CEEB',
        'display_text': '#87CEEB',
        'localized_data': '{}',
        'created_at': '2026-04-13T12:00:00Z',
        'updated_at': '2026-04-13T12:00:00Z',
      };

      final model = CardModel.fromJson(json);
      expect(model.hexColor, '#87CEEB');

      final legacyJson = Map<String, dynamic>.from(json);
      legacyJson['display_text'] = '';
      final legacyModel = CardModel.fromJson(legacyJson);
      expect(legacyModel.hexColor, isNull);
    });

    test('CardModel ignores display_text fallback when it matches answer', () {
      final json = {
        'id': 'test_card_display_match',
        'subject_id': 'subj_1',
        'owner_id': 'user_1',
        'answer': 'Cat',
        'display_text': ' cat ',
        'display_texts': '{"es":"Gato"}',
        'answers': '{"es":"Perro"}',
        'localized_data': '{}',
        'created_at': '2026-04-13T12:00:00Z',
        'updated_at': '2026-04-13T12:00:00Z',
      };

      final model = CardModel.fromJson(json);
      expect(model.hasMeaningfulDisplayText('en'), isFalse);
      expect(model.hasMeaningfulDisplayText('ES'), isTrue);
    });

    test('CardModel treats trimmed case-insensitive matches as equal', () {
      final json = {
        'id': 'test_card_display_trim',
        'subject_id': 'subj_1',
        'owner_id': 'user_1',
        'answer': 'Hello World',
        'display_text': '  hello world  ',
        'localized_data': '{}',
        'created_at': '2026-04-13T12:00:00Z',
        'updated_at': '2026-04-13T12:00:00Z',
      };

      final model = CardModel.fromJson(json);
      expect(model.hasMeaningfulDisplayText('en'), isFalse);
    });

    test('UserModel parses and serializes test_mode', () {
      final model = UserModel.fromJson({
        'id': 'user_1',
        'username': 'Test User',
        'email': 'test@example.com',
        'test_mode': 'random',
      });

      expect(model.testMode, 'random');
      expect(model.toJson()['test_mode'], 'random');
    });

    test('UserModel parses and serializes learn autoplay delay', () {
      final model = UserModel.fromJson({
        'id': 'user_1',
        'username': 'Test User',
        'email': 'test@example.com',
        'learn_autoplay_delay_seconds': 4,
      });

      expect(model.learnAutoplayDelaySeconds, 4);
      expect(model.toJson()['learn_autoplay_delay_seconds'], 4);
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
