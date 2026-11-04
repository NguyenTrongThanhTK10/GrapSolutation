import 'dart:convert';

import '../domain/models.dart';
import '../domain/ride_route.dart';
import '../network/api_client.dart';

class RideRouteRepository {
  final ApiClient client;
  RideRouteRepository(this.client);

  Future<RideRoute> load(String rideId) async {
    final data = await client.request(
      '/rides/${Uri.encodeComponent(rideId)}/route',
    ) as Map<String, dynamic>;
    return RideRoute(
      planned: routeGeometryFromJson(data['geometry']),
      recorded: [
        for (final sample in data['samples'] as List? ?? const [])
          if (sample is Map && _valid(sample['latitude'], sample['longitude']))
            Place(
              id: '${sample['recordedAt']}',
              address: 'Vị trí đã ghi nhận',
              latitude: (sample['latitude'] as num).toDouble(),
              longitude: (sample['longitude'] as num).toDouble(),
            ),
      ],
      distanceMeters: (data['distanceMeters'] as num?)?.toInt() ?? 0,
      durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}

bool _valid(dynamic latitude, dynamic longitude) =>
    latitude is num &&
    longitude is num &&
    latitude.isFinite &&
    longitude.isFinite &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180;

// The map adapter supplies a GeoJSON LineString, using [longitude, latitude].
// Missing or malformed geometry must not prevent viewing the ride receipt.
List<Place> routeGeometryFromJson(dynamic geometry) {
  try {
    if (geometry is String) {
      geometry = jsonDecode(geometry);
    }
    if (geometry is! Map || geometry['type'] != 'LineString') {
      return const [];
    }
    final coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.length < 2) {
      return const [];
    }
    final points = <Place>[];
    for (final coordinate in coordinates) {
      if (coordinate is! List ||
          coordinate.length < 2 ||
          !_valid(coordinate[1], coordinate[0])) {
        return const [];
      }
      points.add(
        Place(
          id: 'route-${points.length}',
          address: 'Tuyến dự kiến',
          latitude: (coordinate[1] as num).toDouble(),
          longitude: (coordinate[0] as num).toDouble(),
        ),
      );
    }
    return List.unmodifiable(points);
  } on FormatException {
    return const [];
  }
}
