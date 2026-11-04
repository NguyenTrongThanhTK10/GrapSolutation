import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ride_route_repository.dart';
import '../domain/ride_route.dart';
import 'app_providers.dart';

final rideRouteRepositoryProvider = Provider(
  (ref) => RideRouteRepository(ref.watch(apiClientProvider)),
);

// Refresh alongside ride status and live driver position updates.
typedef RideRouteKey = ({String id, int version, DateTime? locationAt});
final rideRouteProvider = FutureProvider.autoDispose
    .family<RideRoute, RideRouteKey>((ref, key) {
      ref.watch(sessionProvider);
      return ref.watch(rideRouteRepositoryProvider).load(key.id);
    }, retry: (count, error) => null);
