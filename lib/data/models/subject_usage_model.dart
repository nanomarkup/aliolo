class SubjectUsageModel {
  final String subjectId;
  final String subjectName;
  final String? pillarName;
  final String? folderName;
  final int totalStarted;
  final int totalCompleted;
  final int learnStarted;
  final int learnCompleted;
  final int testStarted;
  final int testCompleted;
  final double completionRate;
  final DateTime? updatedAt;

  const SubjectUsageModel({
    required this.subjectId,
    required this.subjectName,
    this.pillarName,
    this.folderName,
    required this.totalStarted,
    required this.totalCompleted,
    required this.learnStarted,
    required this.learnCompleted,
    required this.testStarted,
    required this.testCompleted,
    required this.completionRate,
    this.updatedAt,
  });

  factory SubjectUsageModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return SubjectUsageModel(
      subjectId: json['subject_id']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? '',
      pillarName: json['pillar_name']?.toString(),
      folderName: json['folder_name']?.toString(),
      totalStarted: parseInt(json['total_started']),
      totalCompleted: parseInt(json['total_completed']),
      learnStarted: parseInt(json['learn_started']),
      learnCompleted: parseInt(json['learn_completed']),
      testStarted: parseInt(json['test_started']),
      testCompleted: parseInt(json['test_completed']),
      completionRate: parseDouble(json['completion_rate']),
      updatedAt: parseDate(json['updated_at']),
    );
  }
}
