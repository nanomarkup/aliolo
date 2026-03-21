import 'subject_model.dart';

class FolderModel {
  final String id;
  final int pillarId;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, LocalizedSubjectData> localizedData;

  FolderModel({
    required this.id,
    required this.pillarId,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
    this.localizedData = const {},
  });

  factory FolderModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> locMap = json['localized_data'] ?? {};
    final localized = locMap.map(
      (key, value) => MapEntry(
        key.toLowerCase(),
        LocalizedSubjectData.fromJson(value as Map<String, dynamic>),
      ),
    );

    return FolderModel(
      id: json['id'],
      pillarId: json['pillar_id'] ?? 1,
      ownerId: json['owner_id'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      localizedData: localized,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pillar_id': pillarId,
      'owner_id': ownerId,
      'localized_data': localizedData.map((k, v) => MapEntry(k, v.toJson())),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
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
    return _getInherited(langCode, (d) => d.name) ?? 'Unnamed Folder';
  }

  String getDescription(String langCode) {
    return _getInherited(langCode, (d) => d.description) ?? '';
  }
}
