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

  List<String> findHardcodedPageStrings() {
    final findings = <String>[];
    final sourceFiles = Directory('${projectRoot.path}/lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.contains('/pages/'))
        .where((file) => file.path.endsWith('.dart'));
    final patterns = <RegExp>[
      RegExp(r'''\b(?:const\s+)?Text\(\s*['"]([^'"]+)['"]'''),
      RegExp(r'''\blabelText\s*:\s*['"]([^'"]+)['"]'''),
      RegExp(r'''\bhintText\s*:\s*['"]([^'"]+)['"]'''),
      RegExp(r'''\btooltip\s*:\s*['"]([^'"]+)['"]'''),
    ];
    final allowed = {
      '',
      '-',
      '•',
      '???',
      'JSON',
      'XP',
      'aliolo',
      'TECHNICAL CONTEXT',
    };

    for (final file in sourceFiles) {
      final content = file.readAsStringSync();
      for (final pattern in patterns) {
        for (final match in pattern.allMatches(content)) {
          final value = match.group(1)!.trim();
          if (allowed.contains(value)) continue;
          if (RegExp(r'^\d+$').hasMatch(value)) continue;
          if (value.startsWith('#')) continue;
          if (RegExp(r'^\$').hasMatch(value)) continue;
          if (RegExp(r'^[a-z0-9_]+$').hasMatch(value)) continue;
          if (value.contains(r'${context.t')) continue;
          if (value.startsWith('UA:')) continue;
          if (value.startsWith('Context:')) continue;
          final line = content.substring(0, match.start).split('\n').length;
          findings.add('${file.path}:$line: $value');
        }
      }
    }

    return findings;
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
      expect(File('${translationsDir.path}/$lang.nano').existsSync(), isTrue);
    }
  });

  test('Flutter page strings use localization keys', () {
    expect(findHardcodedPageStrings(), isEmpty);
  });
}
