import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grap_driver/core/core.dart';
import 'package:grap_driver/features/driving/driver_controller.dart';

class SignedIn extends SessionController {
  @override
  Future<GrapUser?> build() async =>
      const GrapUser(id: 'driver', name: 'Tài xế', role: 'Driver');
}

const point = Place(
  id: 'a',
  address: 'Điểm',
  latitude: 10.77,
  longitude: 106.69,
);
RideSnapshot snapshot(String status, int version, {PaymentSnapshot? payment}) =>
    RideSnapshot(
      id: 'ride',
      code: 'GRTEST',
      status: status,
      version: version,
      service: 'BIKE',
      pickup: point,
      dropoff: point,
      fare: const Fare(payable: 50000, gross: 50000, commission: 10000),
      createdAt: DateTime.utc(2026),
      payment: payment,
    );

class RidesFake implements RideRepository {
  final updatesController = StreamController<void>.broadcast();
  RideSnapshot? current = snapshot('DRIVER_ARRIVED', 3);
  Completer<RideSnapshot?>? nextActive;
  RideSnapshot? completed;
  final records = <RideSnapshot>[];
  Completer<void>? supportWait;
  @override
  Future<void> support(String message, {String? rideId}) async {
    await supportWait?.future;
  }

  bool released = false, failHistory = false, failDetail = false;
  int historyReads = 0, activeReads = 0, cashCalls = 0;
  @override
  Future<void> cash(PaymentSnapshot payment, int amount, String reason) async {
    cashCalls++;
    current = snapshot(
      'COMPLETED',
      5,
      payment: PaymentSnapshot(
        id: payment.id,
        status: 'PENDING',
        payable: payment.payable,
        paid: payment.paid + amount,
      ),
    );
  }

  @override
  Future<RideSnapshot?> active() async {
    activeReads++;
    return nextActive == null ? current : nextActive!.future;
  }

  @override
  Future<RideSnapshot> detail(String id) async {
    if (failDetail) {
      throw const Failure('NETWORK_ERROR', 'Chưa tải được chi tiết');
    }
    if (released) {
      throw const Failure('RESOURCE_NOT_FOUND', 'Assignment đã đóng');
    }
    return current ?? completed!;
  }

  @override
  Future<List<RideSnapshot>> history() async {
    historyReads++;
    if (failHistory) throw const Failure('HTTP_503', 'Chưa tải được lịch sử');
    return records;
  }

  @override
  Stream<void> updates() => updatesController.stream;
  @override
  Future<RideSnapshot> command(
    RideSnapshot ride,
    String command, {
    String? pin,
    String? reason,
    PositionEvidence? position,
    String? completionType,
  }) async {
    current = snapshot('IN_PROGRESS', 4);
    return current!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class DriversFake implements DriverRepository {
  bool failEarnings = false, online = false;
  int locationCalls = 0, heartbeatCalls = 0;
  @override
  Future<void> location(PositionEvidence p) async {
    locationCalls++;
  }

  @override
  Future<void> heartbeat() async {
    heartbeatCalls++;
  }

  int earningsReads = 0;
  @override
  Future<Availability> availability() async => Availability(
    online: online,
    busy: true,
    offlineAfterRide: false,
    deviceActive: true,
    version: 1,
    reviewStatus: 'APPROVED',
  );
  @override
  Future<DriverOffer?> currentOffer() async => null;
  @override
  Future<Earnings> earnings() async {
    earningsReads++;
    if (failEarnings) throw const Failure('HTTP_503', 'Chưa tải được thu nhập');
    return const Earnings(
      completedRides: 0,
      entitlement: 0,
      commission: 0,
      available: 0,
      pending: 0,
      held: 0,
      debt: 0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class RecoveryFake implements RecoveryRepository {
  final entries = <PendingOperation>[];
  @override
  Future<List<PendingOperation>> pending() async => entries;
  @override
  Future<void> retry(String id) async {}
}

class TestPosition implements LocationProvider {
  @override
  Future<PositionEvidence> current() async => PositionEvidence(
    latitude: 10.77,
    longitude: 106.69,
    accuracy: 10,
    recordedAt: DateTime.now().toUtc(),
    sequence: 1,
  );
}

Future<ProviderContainer> setup(
  RidesFake rides, {
  DriversFake? drivers,
  RecoveryFake? recovery,
}) async {
  final container = ProviderContainer(
    overrides: [
      sessionProvider.overrideWith(SignedIn.new),
      rideRepositoryProvider.overrideWithValue(rides),
      driverRepositoryProvider.overrideWithValue(drivers ?? DriversFake()),
      locationProvider.overrideWithValue(TestPosition()),
      recoveryRepositoryProvider.overrideWithValue(recovery ?? RecoveryFake()),
    ],
  );
  await container.read(sessionProvider.future);
  await container.read(driverControllerProvider.future);
  return container;
}

void main() {
  test(
    'an unresolved cash command blocks another collection for the same payment',
    () async {
      final rides = RidesFake()
        ..current = snapshot(
          'COMPLETED',
          5,
          payment: const PaymentSnapshot(
            id: 'p',
            status: 'PENDING',
            payable: 50000,
            paid: 0,
          ),
        );
      final recovery = RecoveryFake()
        ..entries.add(
          PendingOperation(
            'pending',
            '/payments/p/cash-collections',
            DateTime.now(),
          ),
        );
      final c = await setup(rides, recovery: recovery);
      addTearDown(() async {
        c.dispose();
        await rides.updatesController.close();
      });
      await c
          .read(driverControllerProvider.notifier)
          .cash(10000, 'Không được gửi thêm');
      expect(rides.cashCalls, 0);
      expect(
        c.read(driverControllerProvider).value!.error,
        contains('chưa xác nhận'),
      );
    },
  );

  test(
    'GPS and heartbeat continue while a support command is pending',
    () async {
      final rides = RidesFake();
      final drivers = DriversFake()..online = true;
      final c = await setup(rides, drivers: drivers);
      addTearDown(() async {
        c.dispose();
        await rides.updatesController.close();
      });
      rides.supportWait = Completer<void>();
      final controller = c.read(driverControllerProvider.notifier);
      final sending = controller.support('Cần hỗ trợ');
      await Future<void>.delayed(Duration.zero);
      expect(c.read(driverControllerProvider).value!.busy, true);
      await controller.publishLocation();
      expect(drivers.locationCalls, 1);
      expect(drivers.heartbeatCalls, 1);
      rides.supportWait!.complete();
      await sending;
    },
  );

  test(
    'optional earnings and history outages do not hide the current assignment',
    () async {
      final rides = RidesFake()..failHistory = true;
      final drivers = DriversFake()..failEarnings = true;
      final c = await setup(rides, drivers: drivers);
      addTearDown(() async {
        c.dispose();
        await rides.updatesController.close();
      });
      expect(
        c.read(driverControllerProvider).value!.ride!.status,
        'DRIVER_ARRIVED',
      );
      expect(
        c.read(driverControllerProvider).value!.error,
        contains('thu nhập'),
      );
    },
  );
  test('polls refresh the ride and offer while earnings and history wait for the next window', () async {
    final rides = RidesFake();
    final drivers = DriversFake();
    final c = await setup(rides, drivers: drivers);
    addTearDown(() async {
      c.dispose();
      await rides.updatesController.close();
    });
    final controller = c.read(driverControllerProvider.notifier);
    await controller.refresh(forceSupplemental: false);
    await controller.refresh(forceSupplemental: false);
    expect(rides.activeReads, 3);
    expect(rides.historyReads, 1);
    expect(drivers.earningsReads, 1);
    await controller.refresh();
    expect(rides.historyReads, 2);
    expect(drivers.earningsReads, 2);
    await controller.start('1234');
    await controller.refresh(forceSupplemental: false);
    expect(rides.historyReads, 3);
    expect(drivers.earningsReads, 3);
  });
  test('cash is confirmed from its ride detail even when history and earnings fail', () async {
    final rides = RidesFake()
      ..current = snapshot(
        'COMPLETED',
        5,
        payment: const PaymentSnapshot(
          id: 'p',
          status: 'PENDING',
          payable: 50000,
          paid: 0,
        ),
      );
    final drivers = DriversFake();
    final c = await setup(rides, drivers: drivers);
    addTearDown(() async {
      c.dispose();
      await rides.updatesController.close();
    });
    rides.failHistory = true;
    drivers.failEarnings = true;
    await c.read(driverControllerProvider.notifier).cash(20000, 'Thu một phần');
    final state = c.read(driverControllerProvider).value!;
    expect(state.ride!.payment!.paid, 20000);
    expect(state.message, contains('Đã ghi nhận'));
    expect(state.paymentNeedsRefresh, false);
    expect(rides.cashCalls, 1);
  });
  test('cash is locked after confirmation until a fresh payment snapshot is recovered', () async {
    final rides = RidesFake()
      ..current = snapshot(
        'COMPLETED',
        5,
        payment: const PaymentSnapshot(
          id: 'p',
          status: 'PENDING',
          payable: 50000,
          paid: 0,
        ),
      );
    final c = await setup(rides);
    addTearDown(() async {
      c.dispose();
      await rides.updatesController.close();
    });
    final controller = c.read(driverControllerProvider.notifier);
    rides.failHistory = true;
    rides.failDetail = true;
    await controller.cash(20000, 'Thu tiền');
    expect(c.read(driverControllerProvider).value!.paymentNeedsRefresh, true);
    await controller.cash(20000, 'Không được gửi lặp');
    expect(rides.cashCalls, 1);
    rides.current = null;
    rides.failDetail = false;
    // The active endpoint returns null for completed rides; detail remains readable.
    rides.completed = snapshot(
      'COMPLETED',
      5,
      payment: const PaymentSnapshot(
        id: 'p',
        status: 'PENDING',
        payable: 50000,
        paid: 20000,
      ),
    );
    await controller.refresh();
    expect(c.read(driverControllerProvider).value!.paymentNeedsRefresh, false);
    expect(c.read(driverControllerProvider).value!.ride!.payment!.paid, 20000);
  });

  test('a delayed refresh cannot overwrite a just confirmed start', () async {
    final rides = RidesFake();
    final active = await setup(rides);
    rides.nextActive = Completer<RideSnapshot?>();
    final refresh = active.read(driverControllerProvider.notifier).refresh();
    await Future<void>.delayed(Duration.zero);
    await active.read(driverControllerProvider.notifier).start('1234');
    rides.nextActive!.complete(snapshot('DRIVER_ARRIVED', 3));
    await refresh;
    expect(active.read(driverControllerProvider).value!.ride!.version, 4);
    active.dispose();
    await rides.updatesController.close();
  });
  test(
    'released assignment disappears when snapshot access is revoked',
    () async {
      final rides = RidesFake();
      rides.records.add(rides.current!);
      final container = await setup(rides);
      rides.current = null;
      rides.released = true;
      rides.failHistory = true;
      await container.read(driverControllerProvider.notifier).refresh();
      expect(container.read(driverControllerProvider).value!.ride, isNull);
      expect(
        () => container.read(driverControllerProvider.notifier).dismissRide(),
        returnsNormally,
      );
      container.dispose();
      await rides.updatesController.close();
    },
  );
}
