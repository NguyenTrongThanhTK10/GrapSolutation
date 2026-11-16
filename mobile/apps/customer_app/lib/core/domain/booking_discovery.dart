import 'models.dart';

class NearbyDriver {
  final Place location;
  final String service;
  final DateTime freshUntil;
  const NearbyDriver({
    required this.location,
    required this.service,
    required this.freshUntil,
  });
}

class NearbyAvailability {
  final bool inServiceZone;
  final int radiusMeters;
  final Map<String, int> counts;
  final DateTime freshUntil;
  final List<NearbyDriver> drivers;
  const NearbyAvailability({
    required this.inServiceZone,
    required this.radiusMeters,
    required this.counts,
    required this.freshUntil,
    this.drivers = const [],
  });
}

abstract interface class BookingDiscoveryRepository {
  Future<NearbyAvailability> nearby(Place pickup);
  Stream<void> updates(Place pickup);
}
