import 'package:flutter_test/flutter_test.dart';
import 'package:aliolo/features/management/presentation/utils/localized_data_json.dart';

void main() {
  test('folder mode keeps only name fields', () {
    final template = buildLocalizedJsonTemplate(
      LocalizedJsonEditorMode.folder,
      {
        'global': {'name': 'Main', 'description': 'Ignore me'},
        'es': {'name': 'Carpeta', 'description': 'Ignorar'},
      },
    );

    expect(template['global'], {'name': 'Main'});
    expect(template['es'], {'name': 'Carpeta'});

    final parsed = parseLocalizedJsonTemplate(
      LocalizedJsonEditorMode.folder,
      '{"global":{"name":"Updated","description":"Still ignored"}}',
    );

    expect(parsed['global'], {'name': 'Updated'});
    expect(parsed['global']!.containsKey('description'), isFalse);
  });

  test('subject mode keeps names and descriptions', () {
    final template = buildLocalizedJsonTemplate(
      LocalizedJsonEditorMode.subject,
      {
        'global': {'name': 'Sports', 'description': 'Learn sports'},
        'fr': {'name': 'Sports', 'description': 'Apprendre les sports'},
      },
    );

    expect(template['global'], {'name': 'Sports', 'description': 'Learn sports'});
    expect(template['fr'], {'name': 'Sports', 'description': 'Apprendre les sports'});

    final parsed = parseLocalizedJsonTemplate(
      LocalizedJsonEditorMode.subject,
      '{"global":{"name":"Updated","description":"Updated desc","audio":"drop"}}',
    );

    expect(parsed['global'], {'name': 'Updated', 'description': 'Updated desc'});
    expect(parsed['global']!.containsKey('audio'), isFalse);
  });

  test('collection mode follows the same text contract as subject mode', () {
    final parsed = parseLocalizedJsonTemplate(
      LocalizedJsonEditorMode.collection,
      '{"en":{"name":"Collection","description":"Desc","images":[]}}',
    );

    expect(parsed['en'], {'name': 'Collection', 'description': 'Desc'});
    expect(parsed['en']!.containsKey('images'), isFalse);
  });

  test('card mode keeps only prompt answer and displayText', () {
    final template = buildLocalizedJsonTemplate(
      LocalizedJsonEditorMode.card,
      {
        'global': {
          'prompt': 'Prompt',
          'answer': 'Answer',
          'displayText': 'Display',
          'imagesLocal': 'ignore',
        },
      },
    );

    expect(template['global'], {
      'prompt': 'Prompt',
      'answer': 'Answer',
      'displayText': 'Display',
    });

    final parsed = parseLocalizedJsonTemplate(
      LocalizedJsonEditorMode.card,
      '{"global":{"prompt":"P","answer":"A","displayText":"D","audio":"ignore"}}',
    );

    expect(parsed['global'], {
      'prompt': 'P',
      'answer': 'A',
      'displayText': 'D',
    });
    expect(parsed['global']!.containsKey('audio'), isFalse);
  });
}
