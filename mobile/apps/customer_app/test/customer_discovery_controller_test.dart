import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grap_customer/core/core.dart';
import 'package:grap_customer/features/booking/customer_controller.dart';

import 'customer_controller_test.dart'
    show RecoverableRides, setupCustomer, SignedIn;

class PricingRides extends RecoverableRides {
  PricingRides() {
    current = null;
  }
  final requests = <(String, String, String)>[];
  final pending = <Completer<QuoteSnapshot>>[];
  bool hold = false;
  final failures = <String, Failure>{};
  QuoteSnapshot? booked;
  QuoteSnapshot price(String code) => QuoteSnapshot(
    id: 'quote-$code',
    fare: Fare(
      payable: code == 'BIKE'
          ? 35000
          : code == 'CAR_4'
          ? 60000
          : 85000,
      gross: 85000,
      commission: 10000,
    ),
    distanceMeters: 6300,
    durationSeconds: 1200,
    expiresAt: DateTime.now().toUtc().add(const Duration(seconds: 120)),
    source: 'test',
  );
  @override
  Future<QuoteSnapshot> quote(
    Place pickup,
    Place dropoff,
    String service,
  ) async {
    requests.add((pickup.id, dropoff.id, service));
    if (failures[service] != null) throw failures[service]!;
    if (hold) {
      final completer = Completer<QuoteSnapshot>();
      pending.add(completer);
      return completer.future;
    }
    return price(service);
  }

  @override
  Future<RideSnapshot> create(QuoteSnapshot quote) async {
    booked = quote;
    return snapshot('SEARCHING', 1);
  }
}

class LiveAuth implements AuthRepository {
  @override
  Future<bool> get demoMaps async => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class LiveRides extends PricingRides {
  int placeReads = 0;
  @override
  Future<List<Place>> places(String query) async {
    placeReads++;
    return [];
  }
}

void main() {
  test('live startup and refresh do not call empty autocomplete or preselect a sample route', () async {
    final rides = LiveRides();
    final c = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(SignedIn.new),
        authRepositoryProvider.overrideWithValue(LiveAuth()),
        rideRepositoryProvider.overrideWithValue(rides),
      ],
    );
    addTearDown(() async {
      c.dispose();
      await rides.events.close();
    });
    await c.read(sessionProvider.future);
    final state = await c.read(customerControllerProvider.future);
    expect(state.pickup, isNull);
    expect(state.dropoff, isNull);
    expect(rides.placeReads, 0);
    await c.read(customerControllerProvider.notifier).refresh();
    expect(rides.placeReads, 0);
  });
  test('one comparison requests three services in parallel and switching uses the matching quote', () async {
    final rides = PricingRides();
    final c = await setupCustomer(rides);
    final controller = c.read(customerControllerProvider.notifier);
    await controller.quote();
    expect(rides.requests.map((r) => r.$3), ['BIKE', 'CAR_4', 'CAR_7']);
    expect(c.read(customerControllerProvider).value!.quoteOptions.length, 3);
    controller.selectService('CAR_4');
    expect(
      c.read(customerControllerProvider).value!.quote!.fare.payable,
      60000,
    );
    await controller.book();
    expect(rides.booked!.id, 'quote-CAR_4');
    expect(rides.requests.length, 3);
  });
  test('one failed service keeps other valid prices and never books a different service quote', () async {
    final rides = PricingRides()
      ..failures['CAR_4'] = const Failure(
        'SERVICE_UNAVAILABLE',
        'Dịch vụ tạm ngừng',
      );
    final c = await setupCustomer(rides);
    final controller = c.read(customerControllerProvider.notifier);
    await controller.quote();
    controller.selectService('CAR_4');
    expect(c.read(customerControllerProvider).value!.quote, isNull);
    await controller.book();
    expect(rides.booked, isNull);
    controller.selectService('CAR_7');
    await controller.book();
    expect(rides.booked!.id, 'quote-CAR_7');
  });
  test('changing the route during slow comparison invalidates all old prices without blocking selection', () async {
    final rides = PricingRides()..hold = true;
    final c = await setupCustomer(rides);
    final controller = c.read(customerControllerProvider.notifier);
    final flight = controller.quote();
    await Future<void>.delayed(Duration.zero);
    expect(rides.pending.length, 3);
    expect(c.read(customerControllerProvider).value!.busy, isFalse);
    controller.swapPlaces();
    for (var i = 0; i < 3; i++) {
      rides.pending[i].complete(rides.price(['BIKE', 'CAR_4', 'CAR_7'][i]));
    }
    await flight;
    final state = c.read(customerControllerProvider).value!;
    expect(state.pickup!.id, RecoverableRides.dropoff.id);
    expect(state.dropoff!.id, RecoverableRides.pickup.id);
    expect(state.quoteOptions, isEmpty);
    expect(state.quote, isNull);
    expect(state.pricing, isFalse);
    rides.hold = false;
    await controller.quote();
    expect(rides.requests.last.$1, RecoverableRides.dropoff.id);
    expect(c.read(customerControllerProvider).value!.quoteOptions.length, 3);
  });
  test('service selection while quotes load is retained and session failures leave no stuck loading state', () async {
    final rides = PricingRides()..hold = true;
    final c = await setupCustomer(rides);
    final controller = c.read(customerControllerProvider.notifier);
    final flight = controller.quote();
    await Future<void>.delayed(Duration.zero);
    controller.selectService('CAR_7');
    for (var i = 0; i < 3; i++) {
      rides.pending[i].complete(rides.price(['BIKE', 'CAR_4', 'CAR_7'][i]));
    }
    await flight;
    expect(c.read(customerControllerProvider).value!.quote!.id, 'quote-CAR_7');
    rides.hold = false;
    rides.failures['BIKE'] = const Failure('SESSION_CHANGED', 'Phiên đã đổi');
    await controller.quote();
    expect(c.read(customerControllerProvider).value!.pricing, isFalse);
    expect(c.read(customerControllerProvider).value!.quoteOptions, isEmpty);
  });
}
