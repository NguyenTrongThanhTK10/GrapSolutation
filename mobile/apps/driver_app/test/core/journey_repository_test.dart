import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grap_driver/core/data/journey_repository.dart';
import 'package:grap_driver/core/core.dart';

import 'api_client_test.dart'
    show Adapter, client, jsonResponse, session, profile;

const contactJson = {
  'items': [
    {'id': 'p', 'name': 'Người thân', 'phone': '+84912345678', 'version': 1},
  ],
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'expired encrypted contact cache is not offered as current offline data',
    () async {
      final c = client(Adapter((o, _) async => jsonResponse(contactJson)));
      await c.save(session('a'));
      await const FlutterSecureStorage().write(
        key: 'grap.contacts',
        value: '{"actorId":"a","updatedAt":"2026-01-01T00:00:00Z","data":{"items":[]}}',
      );
      expect(await c.readContactCache(c.sessionScope), null);
    },
  );
  test('contact cache survives restart offline but is removed when signing out or switching accounts', () async {
    var online = true;
    final c = client(
      Adapter((o, _) async {
        if (!online) {
          throw DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          );
        }
        return jsonResponse(contactJson);
      }),
    );
    await c.save(session('a'));
    final repository = ApiJourneyRepository(c);
    expect((await repository.contacts()).offline, false);
    online = false;
    final restored = client(
      Adapter(
        (o, _) async => throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        ),
      ),
    );
    await restored.restore();
    expect(
      (await ApiJourneyRepository(restored).contacts()).items.single.phone,
      '+84912345678',
    );
    expect((await ApiJourneyRepository(restored).contacts()).offline, true);
    await restored.clear();
    expect(await const FlutterSecureStorage().read(key: 'grap.contacts'), null);
    await restored.save(session('b'));
    await expectLater(
      ApiJourneyRepository(restored).contacts(),
      throwsA(isA<Failure>()),
    );
  });
  test(
    'late contact response cannot enter a different account cache',
    () async {
      final started = Completer<void>(), release = Completer<void>();
      final c = client(
        Adapter((o, _) async {
          if (o.path == '/me/trusted-contacts') {
            started.complete();
            await release.future;
            return jsonResponse(contactJson);
          }
          return jsonResponse(profile('b'));
        }),
      );
      await c.save(session('a'));
      final pending = ApiJourneyRepository(c).contacts();
      final checked = expectLater(
        pending,
        throwsA(
          isA<Failure>().having((e) => e.code, 'code', 'SESSION_CHANGED'),
        ),
      );
      await started.future;
      await c.save(session('b'));
      release.complete();
      await checked;
      expect(await c.readContactCache(c.sessionScope), null);
    },
  );
  test(
    'a read racing contact deletion cannot restore the removed phone',
    () async {
      final started = Completer<void>(), release = Completer<void>();
      var reads = 0;
      final c = client(
        Adapter((o, _) async {
          if (o.method == 'DELETE') return jsonResponse({'success': true});
          if (reads++ == 0) {
            started.complete();
            await release.future;
            return jsonResponse(contactJson);
          }
          return jsonResponse({'items': []});
        }),
      );
      await c.save(session('a'));
      final repo = ApiJourneyRepository(c);
      final loading = repo.contacts();
      await started.future;
      await repo.deleteContact(
        const TrustedPerson('p', 'Người thân', '+84912345678', 1),
      );
      release.complete();
      expect((await loading).items, isEmpty);
      expect((await c.readContactCache(c.sessionScope))!['items'], isEmpty);
    },
  );
  test('history cursor and local date boundaries are encoded without changing the cursor', () async {
    final from = DateTime(2026, 10, 3), to = DateTime(2026, 10, 4);
    final c = client(
      Adapter((o, _) async {
        final uri = Uri.parse(o.uri.toString());
        expect(uri.queryParameters['cursor'], '+/signed=cursor');
        expect(uri.queryParameters['from'], from.toUtc().toIso8601String());
        expect(uri.queryParameters['to'], to.toUtc().toIso8601String());
        expect(uri.queryParameters['status'], 'COMPLETED');
        return jsonResponse({'items': [], 'nextCursor': null});
      }),
    );
    await c.save(session('a'));
    expect(
      (await ApiJourneyRepository(c).history(
        status: 'COMPLETED',
        from: from,
        to: to,
        cursor: '+/signed=cursor',
      )).nextCursor,
      null,
    );
  });
}
