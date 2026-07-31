enum FriendshipStatus { pending, accepted }

class FriendshipModel {
  final int id;
  final String senderId;
  final String receiverId;
  final FriendshipStatus status;
  final DateTime createdAt;

  FriendshipModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
  });

  factory FriendshipModel.fromJson(Map<String, dynamic> json) {
    return FriendshipModel(
      id: json['id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      status: FriendshipStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => FriendshipStatus.pending,
      ),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
