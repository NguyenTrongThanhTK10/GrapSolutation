import 'models.dart';

class RideRoute {
  final List<Place> planned, recorded;
  final int distanceMeters, durationSeconds;
  const RideRoute({
    this.planned = const [],
    this.recorded = const [],
    this.distanceMeters = 0,
    this.durationSeconds = 0,
  });
}
