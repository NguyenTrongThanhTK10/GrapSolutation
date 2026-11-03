import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grap_customer/core/core.dart';
import 'package:grap_customer/features/booking/customer_controller.dart';

class SignedIn extends SessionController {
  @override
  Future<GrapUser?> build() async =>
      const GrapUser(id: 'customer', name: 'Khách hàng', role: 'Customer');
}

class FakeAuth implements AuthRepository {
  @override
  Future<bool> get demoMaps async => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class RecoverableRides implements RideRepository {
  final events = StreamController<void>.broadcast();
  static const pickup = Place(
    id: 'a',
    address: 'Điểm đón',
    latitude: 10.77,
    longitude: 106.69,
  );
  static const dropoff = Place(
    id: 'b',
    address: 'Điểm đến',
    latitude: 10.79,
    longitude: 106.72,
  );
  RideSnapshot? current;
  final List<RideSnapshot> records = [];
  int historyReads = 0, activeReads = 0;
  bool failHistory = false, revoked = false;
  @override
  Future<RideSnapshot> detail(String id) async {
    if (revoked) {
      throw const Failure('RESOURCE_NOT_FOUND', 'Không còn quyền xem chuyến');
    }
    return current!;
  }

  RecoverableRides() {
    current = snapshot('ASSIGNED', 2);
  }
  RideSnapshot snapshot(String status, int version) => RideSnapshot(
    id: 'ride',
    code: 'GRTEST',
    status: status,
    service: 'BIKE',
    version: version,
    pickup: pickup,
    dropoff: dropoff,
    fare: const Fare(payable: 50000, gross: 50000, commission: 10000),
    createdAt: DateTime.utc(2026, 11, 3),
  );
  @override
  Future<List<Place>> places(String query) async => [pickup, dropoff];
  @override
  Future<RideSnapshot?> active() async {
    activeReads++;
    return current;
  }

  @override
  Future<List<RideSnapshot>> history() async {
    historyReads++;
    if (failHistory) throw const Failure('HTTP_503', 'Không tải được lịch sử');
    return records;
  }

  @override
  Stream<void> updates() => events.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<ProviderContainer> setupCustomer(RecoverableRides rides) async {
  final c = ProviderContainer(
    overrides: [
      sessionProvider.overrideWith(SignedIn.new),
      authRepositoryProvider.overrideWithValue(FakeAuth()),
      rideRepositoryProvider.overrideWithValue(rides),
    ],
  );
  addTearDown(() async {
    c.dispose();
    await rides.events.close();
  });
  await c.read(sessionProvider.future);
  await c.read(customerControllerProvider.future);
  return c;
}

void main() {
  test(
    'history failure during startup does not hide the active ride',
    () async {
      final rides = RecoverableRides()..failHistory = true;
      final c = await setupCustomer(rides);
      expect(
        c.read(customerControllerProvider).value!.ride!.status,
        'ASSIGNED',
      );
      expect(
        c.read(customerControllerProvider).value!.error,
        contains('lịch sử'),
      );
    },
  );
  test(
    'a successful ride refresh is applied when history temporarily fails',
    () async {
      final rides = RecoverableRides();
      final c = await setupCustomer(rides);
      rides.failHistory = true;
      rides.current = rides.snapshot('IN_PROGRESS', 4);
      await c.read(customerControllerProvider.notifier).refresh();
      expect(c.read(customerControllerProvider).value!.ride!.version, 4);
    },
  );
  test('frequent polling skips history while manual refresh and ride changes reload it', () async {
    final rides = RecoverableRides();
    final c = await setupCustomer(rides);
    final controller = c.read(customerControllerProvider.notifier);
    await controller.refresh(forceSupplemental: false);
    await controller.refresh(forceSupplemental: false);
    expect(rides.activeReads, 3);
    expect(rides.historyReads, 1);
    await controller.refresh();
    expect(rides.historyReads, 2);
    rides.current = rides.snapshot('IN_PROGRESS', 4);
    await controller.refresh(forceSupplemental: false);
    expect(rides.historyReads, 3);
  });
  test(
    'revoked ride data is cleared and new booking cannot hide an active ride',
    () async {
      final rides = RecoverableRides();
      rides.records.add(rides.current!);
      final c = await setupCustomer(rides);
      final controller = c.read(customerControllerProvider.notifier);
      controller.newBooking();
      expect(c.read(customerControllerProvider).value!.ride, isNotNull);
      rides.current = null;
      rides.revoked = true;
      rides.failHistory = true;
      await controller.refresh();
      expect(c.read(customerControllerProvider).value!.ride, isNull);
    },
  );
  test(
    'background notifications do not fetch rides and resume forces recovery',
    () async {
      final rides = RecoverableRides();
      final c = await setupCustomer(rides);
      final controller = c.read(customerControllerProvider.notifier);
      controller.setForeground(false);
      rides.events.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(rides.activeReads, 1);
      controller.setForeground(true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(rides.activeReads, 2);
    },
  );

  test('restores active ride and recovers a terminal snapshot after realtime notification', () async {
    final rides = RecoverableRides();
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(SignedIn.new),
        authRepositoryProvider.overrideWithValue(FakeAuth()),
        rideRepositoryProvider.overrideWithValue(rides),
      ],
    );
    await container.read(sessionProvider.future);
    final state = await container.read(customerControllerProvider.future);
    expect(state.ride?.version, 2);
    rides.records.add(rides.snapshot('COMPLETED', 5));
    rides.current = null;
    rides.events.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      container.read(customerControllerProvider).value!.ride!.status,
      'COMPLETED',
    );
    container.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(rides.events.hasListener, isFalse);
    await rides.events.close();
  });
}
