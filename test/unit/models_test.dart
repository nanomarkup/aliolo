import 'package:flutter_test/flutter_test.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/collection_model.dart';

void main() {
  group('Model Boolean Parsing Tests', () {
    test('SubjectModel correctly parses is_public and is_on_dashboard from int', () {
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
    });

    test('CollectionModel correctly parses is_public and is_on_dashboard from int', () {
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
    });

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
  });
}
