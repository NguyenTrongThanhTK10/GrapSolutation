import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

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
      '/customers/me/nearby-drivers?$query',
    ) as Map<String, dynamic>;
    final serverTime = DateTime.parse(j['serverTime'] as String).toUtc();
    return NearbyAvailability(
      inServiceZone: j['inServiceZone'] as bool,
      radiusMeters: (j['radiusMeters'] as num).toInt(),
      counts: {
        for (final item in j['items'] as List)
          item['code'] as String: (item['availableCount'] as num).toInt(),
      },
      freshUntil: started.add(const Duration(seconds: 15)),
      drivers: [
        for (final item in (j['drivers'] as List? ?? const []))
          if (const [
            'BIKE',
            'CAR_4',
            'CAR_7',
          ].contains(item['serviceTypeCode']))
            NearbyDriver(
              location: Place(
                id: item['markerId'] as String,
                address: 'Xe gần điểm đón',
                latitude: (item['latitude'] as num).toDouble(),
                longitude: (item['longitude'] as num).toDouble(),
              ),
              service: item['serviceTypeCode'] as String,
              // Use server-relative age and include request latency in the expiry.
              freshUntil: started.add(
                Duration(
                  milliseconds: DateTime.parse(item['locationAt'] as String)
                      .toUtc()
                      .add(const Duration(seconds: 30))
                      .difference(serverTime)
                      .inMilliseconds
                      .clamp(0, 30000),
                ),
              ),
            ),
      ],
    );
  }

  @override
  Stream<void> updates(Place pickup) {
    late StreamController<void> stream;
    HubConnection? hub;
    var disposed = false;
    Future<void> subscribe() async {
      try {
        await hub!.invoke(
          'SubscribeNearby',
          args: [pickup.latitude, pickup.longitude],
        );
        if (!disposed) stream.add(null);
      } catch (_) {
        // The provider's REST timer also recovers from connection or subscription failures.
      }
    }

    stream = StreamController<void>(
      onListen: () async {
        hub = HubConnectionBuilder()
            .withUrl(
              '${client.baseUrl}/hubs/rides',
              options: HttpConnectionOptions(
                accessTokenFactory: client.accessToken,
              ),
            )
            .withAutomaticReconnect()
            .build();
        hub!.on('nearby.drivers.changed', (_) {
          if (!disposed) stream.add(null);
        });
        hub!.onreconnected(({connectionId}) {
          if (!disposed) unawaited(subscribe());
        });
        try {
          await hub!.start();
          if (!disposed) await subscribe();
        } catch (_) {
          // REST polling remains active when SignalR is unavailable.
        }
        if (disposed) await hub?.stop();
      },
      onCancel: () async {
        disposed = true;
        await hub?.stop();
      },
    );
    return stream.stream;
  }
}
