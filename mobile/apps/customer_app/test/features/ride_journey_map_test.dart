import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grap_customer/core/core.dart';
import 'package:grap_customer/core/domain/ride_route.dart';
import 'package:grap_customer/core/providers/ride_route_providers.dart';
import 'package:grap_customer/features/journey/presentation/ride_journey_map.dart';
import 'package:grap_customer/features/booking/customer_controller.dart';

const pickup = Place(
  id: 'p',
  address: 'Điểm đón',
  latitude: 10.77,
  longitude: 106.69,
);
const bend = Place(
  id: 'b',
  address: 'Đường đi',
  latitude: 10.78,
  longitude: 106.71,
);
const dropoff = Place(
  id: 'd',
  address: 'Điểm đến',
  latitude: 10.79,
  longitude: 106.72,
);
RideSnapshot ride({int version = 1, String status = 'COMPLETED'}) =>
    RideSnapshot(
      id: 'ride',
      code: 'GR-1',
      status: status,
      service: 'BIKE',
      version: version,
      pickup: pickup,
      dropoff: dropoff,
      fare: const Fare(payable: 20000, gross: 20000, commission: 3000),
      createdAt: DateTime.utc(2026, 11, 3),
    );
const route = RideRoute(
  planned: [pickup, bend, dropoff],
  recorded: [pickup, bend],
  distanceMeters: 6300,
  durationSeconds: 1200,
);

class LiveRide extends CustomerController {
  @override
  Future<CustomerState> build() async =>
      CustomerState(ride: ride(status: 'IN_PROGRESS'));
  void updateRide() => state = AsyncData(
    CustomerState(ride: ride(version: 2, status: 'IN_PROGRESS')),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => Directory.systemTemp.path,
        ),
  );

  testWidgets(
    'planned and recorded routes survive opening the full screen map',
    (t) async {
      await t.pumpWidget(
        ProviderScope(
          retry: (count, error) => null,
          overrides: [
            rideRouteProvider.overrideWith((ref, key) async => route),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: RideJourneyMap(ride: ride()),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Tuyến dự kiến'), findsOneWidget);
      expect(find.text('GPS đã ghi nhận'), findsOneWidget);
      expect(find.text('Dự kiến: 6.3 km · 20 phút'), findsOneWidget);
      expect(
        t.widget<PolylineLayer>(find.byType(PolylineLayer)).polylines,
        hasLength(2),
      );
      await t.tap(find.byTooltip('Mở bản đồ toàn màn hình'));
      await t.pumpAndSettle();
      expect(find.text('Hành trình GR-1'), findsOneWidget);
      expect(find.text('GPS đã ghi nhận'), findsOneWidget);
      expect(find.byTooltip('Xem toàn bộ hành trình'), findsOneWidget);
      expect(t.takeException(), isNull);
      t.view.physicalSize = const Size(844, 390);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('full screen keeps following the active trip updates', (t) async {
    final live = LiveRide();
    final versions = <int>[];
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          customerControllerProvider.overrideWith(() => live),
          rideRouteProvider.overrideWith((ref, key) async {
            versions.add(key.version);
            return route;
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RideJourneyMap(ride: ride(status: 'IN_PROGRESS')),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Mở bản đồ toàn màn hình'));
    await t.pumpAndSettle();
      live.updateRide();
    await t.pumpAndSettle();
    expect(versions, contains(2));
    expect(find.text('GPS đã ghi nhận'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'a failed route can retry and missing geometry is labelled honestly',
    (t) async {
      var requests = 0;
      await t.pumpWidget(
        ProviderScope(
          retry: (count, error) => null,
          overrides: [
            rideRouteProvider.overrideWith((ref, key) async {
              if (requests++ == 0) {
                throw const Failure('NETWORK_ERROR', 'Offline');
              }
              return const RideRoute();
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: RideJourneyMap(ride: ride())),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Chưa tải được tuyến đường.'), findsOneWidget);
      await t.tap(find.text('Thử lại tuyến đường'));
      await t.pumpAndSettle();
      expect(find.textContaining('Đường nét đứt chỉ nối'), findsOneWidget);
      expect(find.text('GPS đã ghi nhận'), findsNothing);
      expect(requests, 2);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
}
