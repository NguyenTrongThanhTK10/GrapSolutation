import '../domain/models.dart';
import '../domain/booking_discovery.dart';
import '../network/api_client.dart';

class ApiBookingDiscoveryRepository implements BookingDiscoveryRepository {
  final ApiClient client;
  ApiBookingDiscoveryRepository(this.client);
  @override
  Future<NearbyAvailability> nearby(Place pickup) async {
    final started = DateTime.now();
    final query = Uri(
      queryParameters: {
        'latitude': '${pickup.latitude}',
        'longitude': '${pickup.longitude}',
      },
    ).query;
    final j = await client.request(
      '/customers/me/nearby-services?$query',
    ) as Map<String, dynamic>;
    return NearbyAvailability(
      inServiceZone: j['inServiceZone'] as bool,
      radiusMeters: (j['radiusMeters'] as num).toInt(),
      counts: {
        for (final item in j['items'] as List)
          item['code'] as String: (item['availableCount'] as num).toInt(),
      },
      freshUntil: started.add(const Duration(seconds: 20)),
    );
  }
}
