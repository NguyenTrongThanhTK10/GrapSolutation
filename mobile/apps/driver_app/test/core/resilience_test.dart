import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grap_driver/core/network/api_client.dart';
import 'package:grap_driver/core/core.dart';

import 'api_client_test.dart'
    show Adapter, client, jsonResponse, session, profile;

class DelayedStorage extends FlutterSecureStorage {
  final started = Completer<void>(), release = Completer<void>();
  bool delayRead = false;
  String? delayToken;
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final value = await super.read(key: key);
    if (delayRead && key == 'grap.session') {
      delayRead = false;
      started.complete();
      await release.future;
    }
    return value;
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (key == 'grap.session' &&
        value != null &&
        delayToken != null &&
        (jsonDecode(value) as Map)['accessToken'] == delayToken) {
      started.complete();
      await release.future;
    }
    await super.write(key: key, value: value);
  }
}

ApiClient withStorage(DelayedStorage storage, Adapter adapter) => ApiClient(
  'http://test.invalid',
  storage,
  transport: Dio()..httpClientAdapter = adapter,
);
Matcher failure(String code) =>
    isA<Failure>().having((e) => e.code, 'code', code);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'valid JSON with an invalid session shape is cleared without crashing',
    () async {
      for (final raw in [
        '[]',
        '{"user":[]}',
        '{"accessToken":"x","refreshToken":"r","expiresAt":"invalid","user":{"id":"a","name":"A","role":"Customer"}}',
      ]) {
        await const FlutterSecureStorage().write(
          key: 'grap.session',
          value: raw,
        );
        var requests = 0;
        final c = client(
          Adapter((o, _) async {
            requests++;
            return jsonResponse(profile('a'));
          }),
        );
        expect(await c.restore(), null);
        expect(requests, 0);
        expect(
          await const FlutterSecureStorage().read(key: 'grap.session'),
          null,
        );
      }
    },
  );
  test('damaged journal entries are skipped while valid retries and the session survive', () async {
    final c = client(
      Adapter(
        (o, _) async => throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        ),
      ),
    );
    await c.save(session('a'));
    await expectLater(
      c.request(
        '/rides/r/complete',
        method: 'POST',
        body: {'expectedVersion': 4},
        idempotent: true,
      ),
      throwsA(isA<Failure>()),
    );
    final store = const FlutterSecureStorage();
    final j = jsonDecode(
      (await store.read(key: 'grap.pending'))!,
    ) as Map<String, dynamic>;
    (j['entries'] as Map)['broken-entry'] = ['wrong shape'];
    await store.write(key: 'grap.pending', value: jsonEncode(j));
    final restored = client(
      Adapter((o, _) async => jsonResponse(profile('a'))),
    );
    expect((await restored.restore())!['user']['id'], 'a');
    expect(await restored.pending(), hasLength(1));
  });
  test(
    'malformed cached contacts are ignored without a type cast crash',
    () async {
      final c = client(Adapter((o, _) async => jsonResponse({})));
      await c.save(session('a'));
      for (final data in [
        [],
        {
          'items': [
            {'id': 'bad'},
          ],
        },
        'wrong shape',
      ]) {
        await const FlutterSecureStorage().write(
          key: 'grap.contacts',
          value: jsonEncode({
            'actorId': 'a',
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
            'data': data,
          }),
        );
        expect(await c.readContactCache(c.sessionScope), null);
      }
    },
  );
  test(
    'a delayed restore read cannot resurrect the previous account',
    () async {
      final storage = DelayedStorage();
      await storage.write(key: 'grap.session', value: jsonEncode(session('a')));
      storage.delayRead = true;
      final c = withStorage(
        storage,
        Adapter((o, _) async => jsonResponse(profile('a'))),
      );
      final restoring = c.restore();
      final assertion = expectLater(
        restoring,
        throwsA(failure('SESSION_CHANGED')),
      );
      await storage.started.future;
      await c.save(session('b', 'token-b'));
      storage.release.complete();
      await assertion;
      expect(
        jsonDecode((await storage.read(key: 'grap.session'))!)['user']['id'],
        'b',
      );
    },
  );
  test(
    'a slow refresh storage write cannot overwrite a newer login on disk',
    () async {
      final storage = DelayedStorage();
      final c = withStorage(
        storage,
        Adapter(
          (o, _) async => o.path == '/auth/token/refresh'
              ? jsonResponse(session('a', 'refreshed-a'))
              : jsonResponse({}, 401),
        ),
      );
      await c.save(session('a'));
      storage.delayToken = 'refreshed-a';
      final request = c.request('/me');
      final assertion = expectLater(
        request,
        throwsA(failure('SESSION_CHANGED')),
      );
      await storage.started.future;
      final signingIn = c.save(session('b', 'token-b'));
      await Future<void>.delayed(Duration.zero);
      storage.release.complete();
      await signingIn;
      await assertion;
      expect(
        jsonDecode((await storage.read(key: 'grap.session'))!)['user']['id'],
        'b',
      );
    },
  );
  test(
    'an unauthorized retry after refresh expires the session once',
    () async {
      final c = client(
        Adapter(
          (o, _) async => o.path == '/auth/token/refresh'
              ? jsonResponse(session('a', 'refreshed'))
              : jsonResponse({}, 401),
        ),
      );
      await c.save(session('a'));
      var ended = 0;
      final subscription = c.sessionEnded.listen((_) {
        ended++;
      });
      await expectLater(c.request('/me'), throwsA(failure('SESSION_EXPIRED')));
      await Future<void>.delayed(Duration.zero);
      expect(ended, 1);
      expect(
        await const FlutterSecureStorage().read(key: 'grap.session'),
        null,
      );
      await subscription.cancel();
    },
  );
  test(
    'invalid or foreign refresh sessions do not replace the current account',
    () async {
      for (final bad in [<dynamic>[], session('different-user')]) {
        final c = client(
          Adapter(
            (o, _) async => o.path == '/auth/token/refresh'
                ? jsonResponse(bad)
                : jsonResponse({}, 401),
          ),
        );
        await c.save(session('a'));
        await expectLater(
          c.request('/me'),
          throwsA(failure('INVALID_AUTH_RESPONSE')),
        );
        expect(
          jsonDecode(
            (await const FlutterSecureStorage().read(key: 'grap.session'))!,
          )['user']['id'],
          'a',
        );
      }
    },
  );
}
