import 'dart:convert';
import 'subject_model.dart';
import 'content_item.dart';

class CollectionModel implements ContentItem {
  @override
  final String id;
  @override
  final int pillarId;
  @override
  final String? folderId;
  @override
  final String ownerId;
  @override
  String? ownerName;
  final bool isPublic;
  final String ageGroup;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final Map<String, LocalizedSubjectData> localizedData;
  final List<String> subjectIds;
  bool isOnDashboard;

  @override
  ContentType get type => ContentType.collection;

  CollectionModel({
    required this.id,
    required this.pillarId,
    this.folderId,
    required this.ownerId,
    this.ownerName,
    this.isPublic = false,
    this.ageGroup = '15_plus',
    required this.createdAt,
    required this.updatedAt,
    this.localizedData = const {},
    this.subjectIds = const [],
    this.isOnDashboard = false,
  });

  factory CollectionModel.fromJson(Map<String, dynamic> json) {
    var locData = json['localized_data'];
    Map<String, dynamic> locMap = {};
    if (locData is Map) {
      locMap = Map<String, dynamic>.from(locData);
    } else if (locData is String && locData.isNotEmpty) {
      try {
        locMap = Map<String, dynamic>.from(jsonDecode(locData));
      } catch (_) {}
    }

    final Map<String, LocalizedSubjectData> localized = {};
    locMap.forEach((key, value) {
      if (value is Map) {
        localized[key.toLowerCase()] = LocalizedSubjectData.fromJson(Map<String, dynamic>.from(value));
      }
    });

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
      isPublic: json['is_public'] == true || json['is_public'] == 1,
      ageGroup: json['age_group'] ?? '15_plus',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      localizedData: localized,
      subjectIds: subjects,
      isOnDashboard: json['is_on_dashboard'] == true || json['is_on_dashboard'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pillar_id': pillarId,
      'folder_id': folderId,
      'owner_id': ownerId,
      'is_public': isPublic,
      'age_group': ageGroup,
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

  static String capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String getName(String langCode) {
    final name = _getInherited(langCode, (d) => d.name) ?? 'Unnamed Collection';
    return capitalizeFirst(name);
  }

  String getDescription(String langCode) {
    final desc = _getInherited(langCode, (d) => d.description) ?? '';
    return capitalizeFirst(desc);
  }
}
