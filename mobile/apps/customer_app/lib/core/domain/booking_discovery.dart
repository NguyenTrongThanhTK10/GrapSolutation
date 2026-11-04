import 'models.dart';

class NearbyAvailability {
  final bool inServiceZone;
  final int radiusMeters;
  final Map<String, int> counts;
  final DateTime freshUntil;
  const NearbyAvailability({
    required this.inServiceZone,
    required this.radiusMeters,
    required this.counts,
    required this.freshUntil,
  });
}

abstract interface class BookingDiscoveryRepository {
  Future<NearbyAvailability> nearby(Place pickup);
}
