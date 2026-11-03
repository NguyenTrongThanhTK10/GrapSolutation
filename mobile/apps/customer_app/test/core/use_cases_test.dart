import 'package:flutter_test/flutter_test.dart';
import 'package:grap_customer/core/core.dart';
import 'package:grap_customer/core/data/mappers.dart';

class FakeRides implements RideRepository {
  var calls = 0;
  @override
  Future<RideSnapshot> create(QuoteSnapshot quote) {
    calls++;
    throw UnimplementedError();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeDrivers implements DriverRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeLocation implements LocationProvider {
  @override
  Future<PositionEvidence> current() => throw UnimplementedError();
}

void main() {
  const pickup = Place(
    id: 'a',
    address: 'Điểm đón',
    latitude: 10.7721,
    longitude: 106.6983,
  );
  test('expired quote cannot create a new command', () async {
    final rides = FakeRides();
    final useCase = CustomerUseCases(rides);
    final quote = QuoteSnapshot(
      id: 'expired',
      fare: const Fare(payable: 50000, gross: 50000, commission: 10000),
      distanceMeters: 6000,
      durationSeconds: 1200,
      expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      source: 'TEST',
    );
    expect(() => useCase.book(quote), throwsA(isA<Failure>()));
    expect(rides.calls, 0);
  });
  test('identical points require a new destination', () {
    expect(
      () => CustomerUseCases(FakeRides()).quote(pickup, pickup, 'BIKE'),
      throwsA(isA<Failure>()),
    );
  });
  test('driver use case rejects malformed PIN before sending', () {
    final useCase = DriverUseCases(FakeRides(), FakeDrivers(), FakeLocation());
    final ride = RideSnapshot(
      id: 'ride',
      code: 'GRTEST',
      status: 'DRIVER_ARRIVED',
      service: 'BIKE',
      version: 3,
      pickup: pickup,
      dropoff: pickup,
      fare: Fare(payable: 50000, gross: 50000, commission: 10000),
      createdAt: _testDate,
    );
    expect(() => useCase.start(ride, 'abc'), throwsA(isA<Failure>()));
  });
  test('terminal snapshot accepts redacted GPS and preserves VND amounts', () {
    final ride = rideFromJson({
      'rideId': 'ride',
      'rideCode': 'GRTEST',
      'status': 'COMPLETED',
      'serviceTypeCode': 'BIKE',
      'version': 5,
      'createdAt': '2026-11-03T03:00:00Z',
      'pickup': {'latitude': 10.77, 'longitude': 106.69, 'address': 'A'},
      'dropoff': {'latitude': 10.79, 'longitude': 106.72, 'address': 'B'},
      'fare': {
        'customerPayable': 50000,
        'grossFare': 50000,
        'platformCommission': 10000,
      },
      'driver': {
        'name': 'Tài xế',
        'vehicle': 'Honda',
        'plate': '59-X',
        'color': 'Đen',
        'latitude': null,
        'longitude': null,
        'locationAt': null,
      },
      'payment': {
        'id': 'payment',
        'status': 'PENDING',
        'payableAmount': 50000,
        'paidAmount': 20000,
      },
    });
    expect(ride.driver!.location, isNull);
    expect(ride.payment!.remaining, 30000);
    expect(ride.active, isFalse);
  });
}

final _testDate = DateTime.utc(2026, 11, 3);
