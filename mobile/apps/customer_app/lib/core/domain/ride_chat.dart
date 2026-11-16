class RideMessage {
  final String id, assignmentId, senderId, body;
  final int sequence;
  final DateTime createdAt;
  const RideMessage({
    required this.id,
    required this.assignmentId,
    required this.senderId,
    required this.body,
    required this.sequence,
    required this.createdAt,
  });

  factory RideMessage.fromJson(Map<String, dynamic> json) => RideMessage(
    id: json['id'] as String,
    assignmentId: json['assignmentId'] as String,
    senderId: json['senderId'] as String,
    body: json['body'] as String,
    sequence: json['sequence'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class RideChatPage {
  final String assignmentId, rideCode, peerName;
  final bool canSend, hasMore;
  final int? nextBeforeSequence;
  final List<RideMessage> items;
  const RideChatPage({
    required this.assignmentId,
    required this.rideCode,
    required this.peerName,
    required this.canSend,
    required this.items,
    this.hasMore = false,
    this.nextBeforeSequence,
  });
}

abstract interface class RideChatRepository {
  Future<RideChatPage> load(
    String rideId, {
    int? beforeSequence,
    int? afterSequence,
  });
  Future<RideMessage> send(
    String rideId,
    String assignmentId,
    String body, {
    required String idempotencyKey,
  });
  Stream<void> updates();
}
