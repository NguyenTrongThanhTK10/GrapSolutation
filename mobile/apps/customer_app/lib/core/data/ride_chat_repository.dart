import '../domain/ride_chat.dart';
import '../domain/models.dart';
import '../network/api_client.dart';
import 'repositories.dart';

class ApiRideChatRepository implements RideChatRepository {
  final ApiClient client;
  ApiRideChatRepository(this.client);

  String _path(String rideId) =>
      '/rides/${Uri.encodeComponent(rideId)}/messages';

  @override
  Future<RideChatPage> load(
    String rideId, {
    int? beforeSequence,
    int? afterSequence,
  }) async {
    final query = <String, String>{
      if (beforeSequence != null) 'beforeSequence': '$beforeSequence',
      if (afterSequence != null) 'afterSequence': '$afterSequence',
    };
    final path = Uri(
      path: _path(rideId),
      queryParameters: query.isEmpty ? null : query,
    ).toString();
    final json = await client.request(path) as Map<String, dynamic>;
    return RideChatPage(
      assignmentId: json['assignmentId'] as String,
      rideCode: json['rideCode'] as String,
      peerName: json['peerName'] as String,
      canSend: json['canSend'] as bool,
      hasMore: json['hasMore'] as bool,
      nextBeforeSequence: json['nextBeforeSequence'] as int?,
      items: (json['items'] as List)
          .map((item) => RideMessage.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<RideMessage> send(
    String rideId,
    String assignmentId,
    String body, {
    required String idempotencyKey,
  }) async {
    final text = body.trim();
    if (text.isEmpty || text.length > 1000) {
      throw const Failure('VALIDATION_ERROR', 'Tin nhắn cần từ 1–1.000 ký tự.');
    }
    final json = await client.request(
      _path(rideId),
      method: 'POST',
      body: {'assignmentId': assignmentId, 'body': text},
      idempotent: true,
      idempotencyKey: idempotencyKey,
    ) as Map<String, dynamic>;
    return RideMessage.fromJson(json);
  }

  @override
  Stream<void> updates() => ApiRideRepository(client).updates();
}
