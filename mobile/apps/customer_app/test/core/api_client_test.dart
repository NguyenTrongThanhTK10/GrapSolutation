import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grap_customer/core/network/api_client.dart';
import 'package:grap_customer/core/core.dart';

class Adapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions, Stream<Uint8List>?)
  handler;
  Adapter(this.handler);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) => handler(options, stream);
  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object body, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
Map<String, dynamic> session(String user, [String token = 'old-token']) => {
  'accessToken': token,
  'refreshToken': 'refresh-$user',
  'expiresAt': DateTime.now()
      .toUtc()
      .add(const Duration(hours: 1))
      .toIso8601String(),
  'user': {'id': user, 'name': user, 'role': 'Driver'},
};
Map<String, dynamic> profile(String id) => {
  'id': id,
  'name': id,
  'role': 'Driver',
  'phone': '•••',
  'version': 1,
};
ApiClient client(Adapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return ApiClient(
    'http://test.invalid',
    const FlutterSecureStorage(),
    transport: dio,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'completion retry after restart freezes the original key, GPS and version',
    () async {
      String? originalKey;
      Object? originalBody;
      final original = {
        'expectedVersion': 4,
        'location': {
          'latitude': 10.77,
          'longitude': 106.69,
          'accuracyMeters': 15,
          'recordedAt': '2026-11-03T03:00:00Z',
        },
      };
      final first = client(
        Adapter((o, _) async {
          originalKey = o.headers['Idempotency-Key'] as String;
          originalBody = jsonDecode(jsonEncode(o.data));
          throw DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          );
        }),
      );
      await first.save(session('driver-a'));
      await expectLater(
        first.request(
          '/rides/ride/complete',
          method: 'POST',
          body: original,
          idempotent: true,
        ),
        throwsA(isA<Failure>()),
      );
      expect(await first.pending(), hasLength(1));
      final restored = client(
        Adapter((o, _) async {
          if (o.path == '/me') return jsonResponse(profile('driver-a'));
          expect(o.headers['Idempotency-Key'], originalKey);
          expect(o.data, originalBody);
          return jsonResponse({'status': 'COMPLETED'});
        }),
      );
      await restored.restore();
      expect(await restored.pending(), hasLength(1));
      await restored.request(
        '/rides/ride/complete',
        method: 'POST',
        body: {
          'expectedVersion': 4,
          'location': {'latitude': 20, 'recordedAt': 'DIFFERENT'},
        },
        idempotent: true,
      );
      expect(await restored.pending(), isEmpty);
    },
  );
  test(
    'cash retry retains its operation id and cannot survive account logout',
    () async {
      final c = client(
        Adapter(
          (o, _) async => throw DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          ),
        ),
      );
      await c.save(session('driver-a'));
      await expectLater(
        c.request(
          '/payments/p/cash-collections',
          method: 'POST',
          idempotent: true,
          body: {'operationId': 'cash-p-0-50000', 'collectedAmount': 50000},
        ),
        throwsA(isA<Failure>()),
      );
      expect(await c.pending(), hasLength(1));
      await c.clear();
      await c.save(session('driver-b'));
      expect(await c.pending(), isEmpty);
    },
  );
  test(
    'parallel unauthorized responses share a single refresh flight',
    () async {
      var refreshes = 0;
      final c = client(
        Adapter((o, _) async {
          if (o.path == '/auth/token/refresh') {
            refreshes++;
            await Future<void>.delayed(const Duration(milliseconds: 25));
            return jsonResponse(session('driver-a', 'new-token'));
          }
          return o.headers['Authorization'] == 'Bearer new-token'
              ? jsonResponse(profile('driver-a'))
              : jsonResponse({'code': 'UNAUTHENTICATED'}, 401);
        }),
      );
      await c.save(session('driver-a'));
      await Future.wait(List.generate(10, (_) => c.request('/me')));
      expect(refreshes, 1);
    },
  );
  test(
    'a late refresh response cannot replace the newly signed in account',
    () async {
      final started = Completer<void>(), release = Completer<void>();
      final c = client(
        Adapter((o, _) async {
          if (o.path == '/auth/token/refresh') {
            started.complete();
            await release.future;
            return jsonResponse(session('driver-a', 'late-token'));
          }
          return o.headers['Authorization'] == 'Bearer token-b'
              ? jsonResponse(profile('driver-b'))
              : jsonResponse({}, 401);
        }),
      );
      await c.save(session('driver-a'));
      final request = c.request('/me');
      final assertion = expectLater(
        request,
        throwsA(
          isA<Failure>().having((f) => f.code, 'code', 'SESSION_CHANGED'),
        ),
      );
      await started.future;
      await c.save(session('driver-b', 'token-b'));
      release.complete();
      await assertion;
      expect((await c.request('/me'))['id'], 'driver-b');
    },
  );
  test(
    'raw private upload sends original bytes with content type and length',
    () async {
      final bytes = [137, 80, 78, 71, 13, 10];
      final c = client(
        Adapter((o, stream) async {
          expect(o.contentType, 'image/png');
          expect(o.headers['Content-Length'], bytes.length);
          expect(await stream!.expand((chunk) => chunk).toList(), bytes);
          return jsonResponse({'uploaded': true});
        }),
      );
      await c.save(session('driver-a'));
      await c.request(
        '/files/id/content',
        method: 'PUT',
        bytes: bytes,
        contentType: 'image/png',
      );
    },
  );
  test('PIN commands are not persisted in the durable journal', () async {
    final c = client(
      Adapter(
        (o, _) async => throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        ),
      ),
    );
    await c.save(session('driver-a'));
    await expectLater(
      c.request(
        '/rides/id/start',
        method: 'POST',
        idempotent: true,
        body: {'expectedVersion': 3, 'pickupPin': '9876'},
      ),
      throwsA(isA<Failure>()),
    );
    expect(await c.pending(), isEmpty);
    expect(
      await const FlutterSecureStorage().read(key: 'grap.pending'),
      isNot(contains('9876')),
    );
  });
}
