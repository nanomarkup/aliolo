import 'package:aliolo/data/models/subject_model.dart';

enum ContentType { folder, subject, collection }

abstract class ContentItem {
  String get id;
  int get pillarId;
  String get ownerId;
  String? get folderId;
  String get name;
  Map<String, String> get names;
  String get description;
  Map<String, String> get descriptions;
  DateTime get updatedAt;
  ContentType get type;
  String? get ownerName;
  bool get isOnDashboard;

  String getName(String langCode);
  String getDescription(String langCode);
}
