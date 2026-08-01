import 'dart:io';

import 'package:aliolo/data/services/translation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final projectRoot = Directory.current;
  final translationsDir = Directory('${projectRoot.path}/assets/translations');

  Set<String> parseNanoKeys(File file) {
    final keys = <String>{};
    for (final line in file.readAsLinesSync()) {
      if (!line.startsWith('    ')) continue;
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed == '..') continue;
      keys.add(trimmed.split(' ').first.replaceAll(RegExp(r'\|$'), ''));
    }
    return keys;
  }

  Set<String> findStaticTranslationKeys() {
    final keys = <String>{};
    final sourceFiles = Directory('${projectRoot.path}/lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final pattern = RegExp(
      r'''(?:context\.t|\.translate)\(\s*['"]([a-z0-9_]+)['"]''',
    );

    for (final file in sourceFiles) {
      final content = file.readAsStringSync();
      for (final match in pattern.allMatches(content)) {
        keys.add(match.group(1)!);
      }
    }
    return keys;
  }

  test('localization assets are complete and local-only', () {
    expect(
      File('${projectRoot.path}/remote_bundles.json').existsSync(),
      isFalse,
    );
    expect(File('${translationsDir.path}/ru.nano').existsSync(), isFalse);

    final expectedFiles =
        TranslationService.supportedUILanguages
            .map((lang) => '$lang.nano')
            .toSet();
    final actualFiles =
        translationsDir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.nano'))
            .map((file) => file.uri.pathSegments.last)
            .toSet();

    expect(actualFiles, expectedFiles);

    final englishKeys = parseNanoKeys(File('${translationsDir.path}/en.nano'));
    final sourceKeys = findStaticTranslationKeys();

    expect(englishKeys.containsAll(sourceKeys), isTrue);

    for (final lang in TranslationService.supportedUILanguages) {
      final keys = parseNanoKeys(File('${translationsDir.path}/$lang.nano'));
      expect(
        keys.containsAll(englishKeys),
        isTrue,
        reason: '$lang is missing English keys',
      );
    }
  });
}
