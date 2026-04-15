import 'dart:convert';

class FeedbackModel {
  final String? id;
  final DateTime? createdAt;
  final String userId;
  final String type; // 'bug', 'suggestion', 'other'
  final String title;
  final String content;
  final List<String> attachmentUrls;
  final String status;
  final Map<String, dynamic> metadata;

  // Joined data
  final String? userName;
  final String? userEmail;
  final String? subjectName;

  FeedbackModel({
    this.id,
    this.createdAt,
    required this.userId,
    required this.type,
    required this.title,
    required this.content,
    this.attachmentUrls = const [],
    this.status = 'open',
    this.metadata = const {},
    this.userName,
    this.userEmail,
    this.subjectName,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'user_id': userId,
      'type': type,
      'title': title,
      'content': content,
      'attachment_urls': attachmentUrls,
      'status': status,
      'metadata': metadata,
    };
  }

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    final metadata = _parseMap(json['metadata']);
    return FeedbackModel(
      id: json['id'],
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : null,
      userId: json['user_id'] ?? '',
      type: json['type'] ?? 'suggestion',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      attachmentUrls: _parseStringList(json['attachment_urls']),
      status: json['status'] ?? 'open',
      metadata: metadata,
      userName: json['owner_name'] ?? json['profiles']?['username'],
      userEmail: json['owner_email'] ?? json['profiles']?['email'],
      subjectName: metadata['context'],
    );
  }
}

List<String> _parseStringList(dynamic value) {
  if (value is List) return List<String>.from(value);
  if (value is String && value.isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) return List<String>.from(decoded);
    } catch (_) {}
  }
  return [];
}

Map<String, dynamic> _parseMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String && value.isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return {};
}
