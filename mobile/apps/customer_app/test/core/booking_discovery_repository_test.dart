import 'package:flutter_test/flutter_test.dart';
import 'package:grap_customer/core/data/booking_discovery_repository.dart';

import '../features/booking_ui_test.dart' show pickup;
import 'api_client_test.dart' show Adapter, client, jsonResponse;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('GPS expiry uses server age despite device clock skew', () async {
    final server = DateTime.utc(2030, 1, 1);
    final api = client(
      Adapter((options, _) async {
        expect(options.uri.path, '/api/v1/customers/me/nearby-drivers');
        expect(options.uri.queryParameters['latitude'], '${pickup.latitude}');
        return jsonResponse({
          'inServiceZone': true,
          'radiusMeters': 3000,
          'serverTime': server.toIso8601String(),
          'items': [
            {'code': 'BIKE', 'availableCount': 2},
          ],
          'drivers': [
            for (final seconds in [25, 31])
              {
                'markerId': 'marker-$seconds',
                'serviceTypeCode': 'BIKE',
                'latitude': 10.77,
                'longitude': 106.69,
                'locationAt': server
                    .subtract(Duration(seconds: seconds))
                    .toIso8601String(),
              },
          ],
        });
      }),
    );
    final before = DateTime.now();
    final data = await ApiBookingDiscoveryRepository(api).nearby(pickup);
    expect(data.counts['BIKE'], 2);
    expect(data.drivers.first.location.id, 'marker-25');
    expect(
      data.drivers.first.freshUntil.difference(before).inSeconds,
      inInclusiveRange(4, 5),
    );
    expect(data.drivers.last.freshUntil.isAfter(DateTime.now()), isFalse);
    expect(
      data.freshUntil.difference(before).inSeconds,
      inInclusiveRange(14, 15),
    );
  });
}
