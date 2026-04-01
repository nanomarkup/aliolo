import 'subject_model.dart';
import 'content_item.dart';

class FolderModel implements ContentItem {
  @override
  final String id;
  @override
  final int pillarId;
  @override
  final String ownerId;
  @override
  final String? ownerName;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final Map<String, LocalizedSubjectData> localizedData;
  final int childCount;
  
  @override
  ContentType get type => ContentType.folder;
  @override
  String? get folderId => null; // Folders are top-level or in pillar, not in folders (yet?)
  @override
  bool get isOnDashboard => false;

  FolderModel({
    required this.id,
    required this.pillarId,
    required this.ownerId,
    this.ownerName,
    required this.createdAt,
    required this.updatedAt,
    this.localizedData = const {},
    this.childCount = 0,
  });

  factory FolderModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> locMap = json['localized_data'] ?? {};
    final localized = locMap.map(
      (key, value) => MapEntry(
        key.toLowerCase(),
        LocalizedSubjectData.fromJson(value as Map<String, dynamic>),
      ),
    );

    final Map<String, dynamic>? profile = json['profiles'];

    int count = 0;
    
    // Sum subject counts
    if (json['subjects'] is List) {
      final subjectsList = json['subjects'] as List;
      if (subjectsList.isNotEmpty && subjectsList.first is Map && subjectsList.first['count'] != null) {
        count += (subjectsList.first['count'] as num).toInt();
      } else {
        count += subjectsList.length;
      }
    } else if (json['subjects'] is Map && json['subjects']['count'] != null) {
      count += (json['subjects']['count'] as num).toInt();
    }

    // Sum collection counts
    if (json['collections'] is List) {
      final collectionsList = json['collections'] as List;
      if (collectionsList.isNotEmpty && collectionsList.first is Map && collectionsList.first['count'] != null) {
        count += (collectionsList.first['count'] as num).toInt();
      } else {
        count += collectionsList.length;
      }
    } else if (json['collections'] is Map && json['collections']['count'] != null) {
      count += (json['collections']['count'] as num).toInt();
    }

    return FolderModel(
      id: json['id'],
      pillarId: json['pillar_id'] ?? 1,
      ownerId: json['owner_id'] ?? '',
      ownerName: profile != null ? profile['username'] : null,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      localizedData: localized,
      childCount: count,
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

  static String capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String getName(String langCode) {
    final name = _getInherited(langCode, (d) => d.name) ?? 'Unnamed Folder';
    return capitalizeFirst(name);
  }

  String getDescription(String langCode) {
    final desc = _getInherited(langCode, (d) => d.description) ?? '';
    return capitalizeFirst(desc);
  }
}
