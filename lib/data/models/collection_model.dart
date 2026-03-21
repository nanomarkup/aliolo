import 'subject_model.dart';

class CollectionModel {
  final String id;
  final int pillarId;
  final String? folderId;
  final String ownerId;
  final String? ownerName;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, LocalizedSubjectData> localizedData;
  final List<String> subjectIds;

  CollectionModel({
    required this.id,
    required this.pillarId,
    this.folderId,
    required this.ownerId,
    this.ownerName,
    this.isPublic = false,
    required this.createdAt,
    required this.updatedAt,
    this.localizedData = const {},
    this.subjectIds = const [],
  });

  factory CollectionModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> locMap = json['localized_data'] ?? {};
    final localized = locMap.map(
      (key, value) => MapEntry(
        key.toLowerCase(),
        LocalizedSubjectData.fromJson(value as Map<String, dynamic>),
      ),
    );

    final Map<String, dynamic>? profile = json['profiles'];

    final List<String> subjects = [];
    if (json['collection_items'] is List) {
      for (var item in json['collection_items']) {
        if (item['subject_id'] != null) {
          subjects.add(item['subject_id']);
        }
      }
    }

    return CollectionModel(
      id: json['id'],
      pillarId: json['pillar_id'] ?? 1,
      folderId: json['folder_id'],
      ownerId: json['owner_id'] ?? '',
      ownerName: profile != null ? profile['username'] : null,
      isPublic: json['is_public'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      localizedData: localized,
      subjectIds: subjects,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pillar_id': pillarId,
      'folder_id': folderId,
      'owner_id': ownerId,
      'is_public': isPublic,
      'localized_data': localizedData.map((k, v) => MapEntry(k, v.toJson())),
      'updated_at': updatedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  T? _getInherited<T>(String langCode, T? Function(LocalizedSubjectData) getter) {
    final lang = langCode.toLowerCase();
    if (localizedData.containsKey(lang)) {
      final val = getter(localizedData[lang]!);
      if (val != null) return val;
    }
    if (localizedData.containsKey('global')) {
      final val = getter(localizedData['global']!);
      if (val != null) return val;
    }
    if (localizedData.containsKey('en')) {
      final val = getter(localizedData['en']!);
      if (val != null) return val;
    }
    if (localizedData.isNotEmpty) {
      final val = getter(localizedData.values.first);
      if (val != null) return val;
    }
    return null;
  }

  String getName(String langCode) {
    return _getInherited(langCode, (d) => d.name) ?? 'Unnamed Collection';
  }

  String getDescription(String langCode) {
    return _getInherited(langCode, (d) => d.description) ?? '';
  }
}
