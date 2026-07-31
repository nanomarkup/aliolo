import 'dart:convert';

enum LocalizedJsonEditorMode {
  folder,
  subject,
  collection,
  card,
}

List<String> localizedJsonFieldNames(LocalizedJsonEditorMode mode) {
  switch (mode) {
    case LocalizedJsonEditorMode.folder:
      return ['name'];
    case LocalizedJsonEditorMode.subject:
    case LocalizedJsonEditorMode.collection:
      return ['name', 'description'];
    case LocalizedJsonEditorMode.card:
      return ['prompt', 'answer', 'displayText'];
  }
}

Map<String, dynamic> buildLocalizedJsonTemplate(
  LocalizedJsonEditorMode mode,
  Map<String, Map<String, String>> drafts,
) {
  final fieldNames = localizedJsonFieldNames(mode);
  return {
    for (final entry in drafts.entries)
      entry.key: {
        for (final field in fieldNames) field: entry.value[field] ?? '',
      },
  };
}

Map<String, Map<String, String>> parseLocalizedJsonTemplate(
  LocalizedJsonEditorMode mode,
  String rawJson,
) {
  final decoded = jsonDecode(rawJson);
  if (decoded is! Map) {
    throw const FormatException('Localized JSON must be an object.');
  }

  final fieldNames = localizedJsonFieldNames(mode);
  final result = <String, Map<String, String>>{};

  decoded.forEach((langKey, values) {
    if (values is! Map) return;

    final parsedFields = <String, String>{};
    for (final field in fieldNames) {
      if (values.containsKey(field)) {
        parsedFields[field] = values[field]?.toString() ?? '';
      }
    }

    if (parsedFields.isNotEmpty) {
      result[langKey.toString().toLowerCase()] = parsedFields;
    }
  });

  return result;
}
