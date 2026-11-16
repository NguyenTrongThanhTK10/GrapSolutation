import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grap_customer/core/core.dart';
import 'package:grap_customer/core/data/ride_chat_repository.dart';
import 'package:grap_customer/core/push/push_models.dart';

import 'api_client_test.dart' show Adapter, client, jsonResponse, session;

Map<String, dynamic> messageJson() => {
  'id': 'message-1',
  'assignmentId': 'assignment',
  'senderId': 'a',
  'body': 'Tôi đã đến.',
  'sequence': 1,
  'createdAt': '2026-11-16T01:05:00Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('chat pages preserve assignment, peer and pagination', () async {
    final api = client(
      Adapter((request, _) async {
        expect(request.uri.path, '/api/v1/rides/ride/messages');
        expect(request.uri.queryParameters['beforeSequence'], '51');
        return jsonResponse({
          'assignmentId': 'assignment',
          'rideCode': 'GR1',
          'peerName': 'Tài xế',
          'canSend': false,
          'items': [messageJson()],
          'hasMore': true,
          'nextBeforeSequence': 1,
        });
      }),
    );
    await api.save(session('a'));
    final page = await ApiRideChatRepository(api)
        .load('ride', beforeSequence: 51);
    expect(page.assignmentId, 'assignment');
    expect(page.peerName, 'Tài xế');
    expect(page.canSend, false);
    expect(page.nextBeforeSequence, 1);
    expect(page.items.single.createdAt.isUtc, true);
  });

  test('retry preserves explicit key and assignment while a new identical message gets its own key', () async {
    final keys = <String>[];
    final api = client(
      Adapter((request, _) async {
        keys.add(request.headers['Idempotency-Key'] as String);
        expect(request.data, {
          'assignmentId': 'assignment',
          'body': 'Tôi đã đến.',
        });
        if (keys.length == 1) {
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.connectionError,
          );
        }
        return jsonResponse(messageJson());
      }),
    );
    await api.save(session('a'));
    final repository = ApiRideChatRepository(api);
    await expectLater(
      repository.send(
        'ride',
        'assignment',
        ' Tôi đã đến. ',
        idempotencyKey: 'send-attempt-one',
      ),
      throwsA(isA<Failure>()),
    );
    await repository.send(
      'ride',
      'assignment',
      'Tôi đã đến.',
      idempotencyKey: 'send-attempt-one',
    );
    await repository.send(
      'ride',
      'assignment',
      'Tôi đã đến.',
      idempotencyKey: 'send-attempt-two',
    );
    expect(keys, ['send-attempt-one', 'send-attempt-one', 'send-attempt-two']);
  });

  test('empty and oversized messages do not issue requests', () async {
    var calls = 0;
    final repository = ApiRideChatRepository(
      client(
        Adapter((_, _) async {
          calls++;
          return jsonResponse(messageJson());
        }),
      ),
    );
    for (final body in ['  ', List.filled(1001, 'a').join()]) {
      await expectLater(
        repository.send(
          'ride',
          'assignment',
          body,
          idempotencyKey: 'invalid-message',
        ),
        throwsA(isA<Failure>()),
      );
    }
    expect(calls, 0);
  });

  test('chat push payload is accepted and keeps the ride identifier', () {
    final message = PushMessage.parse({
      'notificationId': 'n',
      'userId': 'a',
      'entityType': 'chat',
      'entityId': 'ride',
    });
    expect(message?.kind, 'chat');
    expect(message?.entityId, 'ride');
  });
}
