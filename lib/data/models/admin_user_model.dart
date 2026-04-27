import 'user_model.dart';

enum AdminUsersFilter { all, free, premium, fake }

extension AdminUsersFilterApi on AdminUsersFilter {
  String get apiValue => name;
}

class AdminSubscriptionModel {
  final String? id;
  final String? userId;
  final String? status;
  final String? provider;
  final String? effectiveSource;
  final DateTime? expiryDate;
  final String? purchaseToken;
  final String? orderId;
  final String? productId;
  final String? activeProviderSubscriptionId;
  final String? activeManualGrantId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AdminSubscriptionModel({
    this.id,
    this.userId,
    this.status,
    this.provider,
    this.effectiveSource,
    this.expiryDate,
    this.purchaseToken,
    this.orderId,
    this.productId,
    this.activeProviderSubscriptionId,
    this.activeManualGrantId,
    this.createdAt,
    this.updatedAt,
  });

  factory AdminSubscriptionModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return AdminSubscriptionModel(
      id: json['id']?.toString(),
      userId: json['user_id']?.toString(),
      status: json['status']?.toString(),
      provider: json['provider']?.toString(),
      effectiveSource: json['effective_source']?.toString(),
      expiryDate: parseDate(json['expiry_date']),
      purchaseToken: json['purchase_token']?.toString(),
      orderId: json['order_id']?.toString(),
      productId: json['product_id']?.toString(),
      activeProviderSubscriptionId:
          json['active_provider_subscription_id']?.toString(),
      activeManualGrantId: json['active_manual_grant_id']?.toString(),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  bool get isActive {
    if (status?.toLowerCase() != 'active') return false;
    if (expiryDate == null) return true;
    return expiryDate!.isAfter(DateTime.now());
  }
}

class AdminUserModel {
  final UserModel profile;
  final AdminSubscriptionModel? subscription;

  AdminUserModel({required this.profile, this.subscription});

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    final subscriptionJson = json['subscription'];
    return AdminUserModel(
      profile: UserModel.fromJson(json),
      subscription:
          subscriptionJson is Map<String, dynamic>
              ? AdminSubscriptionModel.fromJson(subscriptionJson)
              : subscriptionJson is Map
              ? AdminSubscriptionModel.fromJson(
                Map<String, dynamic>.from(subscriptionJson),
              )
              : null,
    );
  }

  String get id => profile.serverId ?? '';
  String get username => profile.username;
  String get email => profile.email;
  bool get isFake => email.toLowerCase().startsWith('fake_');
  bool get isPremium => profile.isPremium || (subscription?.isActive ?? false);
  bool get isFree => !isPremium;
  String get displayName => username.trim().isNotEmpty ? username : email;

  bool matchesFilter(AdminUsersFilter filter) {
    switch (filter) {
      case AdminUsersFilter.all:
        return true;
      case AdminUsersFilter.free:
        return isFree;
      case AdminUsersFilter.premium:
        return isPremium;
      case AdminUsersFilter.fake:
        return isFake;
    }
  }
}

class AdminUsersPageModel {
  final List<AdminUserModel> users;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final int overallCount;

  const AdminUsersPageModel({
    required this.users,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
    required this.overallCount,
  });

  factory AdminUsersPageModel.fromJson(Map<String, dynamic> json) {
    final rawUsers = json['users'];
    final users =
        rawUsers is List
            ? rawUsers
                .whereType<Map>()
                .map(
                  (row) =>
                      AdminUserModel.fromJson(Map<String, dynamic>.from(row)),
                )
                .toList()
            : <AdminUserModel>[];

    int parseInt(dynamic value, {int fallback = 0}) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return AdminUsersPageModel(
      users: users,
      page: parseInt(json['page']),
      pageSize: parseInt(json['pageSize'], fallback: users.length),
      totalCount: parseInt(json['totalCount']),
      totalPages: parseInt(json['totalPages']),
      overallCount: parseInt(json['overallCount']),
    );
  }
}
