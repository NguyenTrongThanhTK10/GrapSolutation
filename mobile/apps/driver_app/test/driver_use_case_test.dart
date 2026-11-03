import 'package:flutter_test/flutter_test.dart';
import 'package:grap_driver/core/core.dart';

class RecordingDrivers implements DriverRepository {
  final List<String> operations = [];
  PositionEvidence? received;
  @override
  Future<void> location(PositionEvidence position) async {
    operations.add('location');
    received = position;
  }

  @override
  Future<void> heartbeat() async {
    operations.add('heartbeat');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class DeviceLocation implements LocationProvider {
  var count = 0;
  @override
  Future<PositionEvidence> current() async {
    count++;
    return PositionEvidence(
      latitude: 10.77,
      longitude: 106.69,
      accuracy: 12,
      recordedAt: DateTime.now().toUtc(),
      sequence: 1,
    );
  }
}

class FakeRides implements RideRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test(
    'location is confirmed before heartbeat eligibility is refreshed',
    () async {
      final drivers = RecordingDrivers(), location = DeviceLocation();
      await DriverUseCases(FakeRides(), drivers, location).publishPosition();
      expect(drivers.operations, ['location', 'heartbeat']);
      expect(location.count, 1);
      expect(drivers.received!.accuracy, 12);
    },
  );
  test(
    'explicit development position does not request device location',
    () async {
      final drivers = RecordingDrivers(), location = DeviceLocation();
      final point = PositionEvidence(
        latitude: 10.8,
        longitude: 106.7,
        accuracy: 15,
        recordedAt: DateTime.now().toUtc(),
        sequence: 2,
      );
      await DriverUseCases(
        FakeRides(),
        drivers,
        location,
      ).publishPosition(developmentPosition: point);
      expect(location.count, 0);
      expect(drivers.received, same(point));
    },
  );
}
