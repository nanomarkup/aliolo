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
    return FeedbackModel(
      id: json['id'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      userId: json['user_id'] ?? '',
      type: json['type'] ?? 'suggestion',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      attachmentUrls: List<String>.from(json['attachment_urls'] ?? []),
      status: json['status'] ?? 'open',
      metadata: json['metadata'] ?? {},
      userName: json['profiles']?['username'],
      userEmail: json['profiles']?['email'],
      subjectName: json['metadata']?['context'],
    );
  }
}
