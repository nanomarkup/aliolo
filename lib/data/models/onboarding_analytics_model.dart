class OnboardingAnalyticsSummaryModel {
  final int totalSessions;
  final int linkedEmailSessions;
  final int ageSelectedSessions;
  final int pillarSelectedSessions;
  final int finalSlideSessions;
  final int uniqueEmails;
  final double? averageLastSlideIndex;
  final double completionRate;
  final int finalSlideIndex;
  final DateTime? latestUpdatedAt;

  const OnboardingAnalyticsSummaryModel({
    required this.totalSessions,
    required this.linkedEmailSessions,
    required this.ageSelectedSessions,
    required this.pillarSelectedSessions,
    required this.finalSlideSessions,
    required this.uniqueEmails,
    required this.averageLastSlideIndex,
    required this.completionRate,
    required this.finalSlideIndex,
    this.latestUpdatedAt,
  });

  factory OnboardingAnalyticsSummaryModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return OnboardingAnalyticsSummaryModel(
      totalSessions: parseInt(json['total_sessions']),
      linkedEmailSessions: parseInt(json['linked_email_sessions']),
      ageSelectedSessions: parseInt(json['age_selected_sessions']),
      pillarSelectedSessions: parseInt(json['pillar_selected_sessions']),
      finalSlideSessions: parseInt(json['final_slide_sessions']),
      uniqueEmails: parseInt(json['unique_emails']),
      averageLastSlideIndex: parseDouble(json['average_last_slide_index']),
      completionRate: parseDouble(json['completion_rate']) ?? 0,
      finalSlideIndex: parseInt(json['final_slide_index']),
      latestUpdatedAt: parseDate(json['latest_updated_at']),
    );
  }
}

class OnboardingAgeBreakdownModel {
  final String ageRange;
  final int sessions;

  const OnboardingAgeBreakdownModel({
    required this.ageRange,
    required this.sessions,
  });

  factory OnboardingAgeBreakdownModel.fromJson(Map<String, dynamic> json) {
    return OnboardingAgeBreakdownModel(
      ageRange: json['age_range']?.toString() ?? 'not_set',
      sessions: int.tryParse(json['sessions']?.toString() ?? '') ?? 0,
    );
  }
}

class OnboardingPillarBreakdownModel {
  final int? pillarId;
  final String pillarName;
  final int sessions;

  const OnboardingPillarBreakdownModel({
    required this.pillarId,
    required this.pillarName,
    required this.sessions,
  });

  factory OnboardingPillarBreakdownModel.fromJson(Map<String, dynamic> json) {
    final rawPillarId = json['pillar_id'];
    return OnboardingPillarBreakdownModel(
      pillarId:
          rawPillarId == null ? null : int.tryParse(rawPillarId.toString()),
      pillarName: json['pillar_name']?.toString() ?? 'Not set',
      sessions: int.tryParse(json['sessions']?.toString() ?? '') ?? 0,
    );
  }
}

class OnboardingSlideBreakdownModel {
  final int? lastSlideIndex;
  final int sessions;

  const OnboardingSlideBreakdownModel({
    required this.lastSlideIndex,
    required this.sessions,
  });

  factory OnboardingSlideBreakdownModel.fromJson(Map<String, dynamic> json) {
    final rawIndex = json['last_slide_index'];
    return OnboardingSlideBreakdownModel(
      lastSlideIndex:
          rawIndex == null ? null : int.tryParse(rawIndex.toString()),
      sessions: int.tryParse(json['sessions']?.toString() ?? '') ?? 0,
    );
  }
}

class OnboardingSessionModel {
  final String sessionId;
  final String? userEmail;
  final String? ageRange;
  final int? pillarId;
  final String? pillarName;
  final int? lastSlideIndex;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OnboardingSessionModel({
    required this.sessionId,
    this.userEmail,
    this.ageRange,
    this.pillarId,
    this.pillarName,
    this.lastSlideIndex,
    this.createdAt,
    this.updatedAt,
  });

  factory OnboardingSessionModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return OnboardingSessionModel(
      sessionId: json['session_id']?.toString() ?? '',
      userEmail: json['user_email']?.toString(),
      ageRange: json['age_range']?.toString(),
      pillarId:
          json['pillar_id'] == null
              ? null
              : int.tryParse(json['pillar_id'].toString()),
      pillarName: json['pillar_name']?.toString(),
      lastSlideIndex:
          json['last_slide_index'] == null
              ? null
              : int.tryParse(json['last_slide_index'].toString()),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }
}

class OnboardingAnalyticsPageModel {
  final OnboardingAnalyticsSummaryModel summary;
  final List<OnboardingAgeBreakdownModel> ageBreakdown;
  final List<OnboardingPillarBreakdownModel> pillarBreakdown;
  final List<OnboardingSlideBreakdownModel> slideBreakdown;
  final List<OnboardingSessionModel> recentSessions;

  const OnboardingAnalyticsPageModel({
    required this.summary,
    required this.ageBreakdown,
    required this.pillarBreakdown,
    required this.slideBreakdown,
    required this.recentSessions,
  });

  factory OnboardingAnalyticsPageModel.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> parseList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }

    return OnboardingAnalyticsPageModel(
      summary: OnboardingAnalyticsSummaryModel.fromJson(
        Map<String, dynamic>.from(json['summary'] as Map),
      ),
      ageBreakdown:
          parseList(
            json['age_breakdown'],
          ).map(OnboardingAgeBreakdownModel.fromJson).toList(),
      pillarBreakdown:
          parseList(
            json['pillar_breakdown'],
          ).map(OnboardingPillarBreakdownModel.fromJson).toList(),
      slideBreakdown:
          parseList(
            json['slide_breakdown'],
          ).map(OnboardingSlideBreakdownModel.fromJson).toList(),
      recentSessions:
          parseList(
            json['recent_sessions'],
          ).map(OnboardingSessionModel.fromJson).toList(),
    );
  }

  static const empty = OnboardingAnalyticsPageModel(
    summary: OnboardingAnalyticsSummaryModel(
      totalSessions: 0,
      linkedEmailSessions: 0,
      ageSelectedSessions: 0,
      pillarSelectedSessions: 0,
      finalSlideSessions: 0,
      uniqueEmails: 0,
      averageLastSlideIndex: null,
      completionRate: 0,
      finalSlideIndex: 6,
    ),
    ageBreakdown: [],
    pillarBreakdown: [],
    slideBreakdown: [],
    recentSessions: [],
  );
}
