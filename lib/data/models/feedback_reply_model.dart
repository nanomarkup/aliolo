import 'dart:convert';

class FeedbackReplyModel {
  final String? id;
  final DateTime? createdAt;
  final String feedbackId;
  final String userId;
  final String content;
  final List<String> attachmentUrls;

  FeedbackReplyModel({
    this.id,
    this.createdAt,
    required this.feedbackId,
    required this.userId,
    required this.content,
    this.attachmentUrls = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'feedback_id': feedbackId,
      'user_id': userId,
      'content': content,
      'attachment_urls': attachmentUrls,
    };
  }

  factory FeedbackReplyModel.fromJson(Map<String, dynamic> json) {
    return FeedbackReplyModel(
      id: json['id'],
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : null,
      feedbackId: json['feedback_id'] ?? '',
      userId: json['user_id'] ?? '',
      content: json['content'] ?? '',
      attachmentUrls: _parseStringList(json['attachment_urls']),
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
