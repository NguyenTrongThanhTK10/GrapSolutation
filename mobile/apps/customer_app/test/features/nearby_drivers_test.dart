import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grap_customer/core/core.dart';
import 'package:grap_customer/features/booking/widgets/nearby_services.dart';
import 'package:latlong2/latlong.dart';

import 'booking_ui_test.dart' show SignedIn, pickup;

class LiveDiscovery implements BookingDiscoveryRepository {
  final signals = StreamController<void>.broadcast();
  final requests = <Place>[];
  final delayed = <String, Completer<NearbyAvailability>>{};
  bool fail = false, staleDriver = false, staleSnapshot = false;
  double latitude = 10.773;
  int subscriptions = 0, cancellations = 0;

  NearbyAvailability snapshot(Place place) => NearbyAvailability(
    inServiceZone: true,
    radiusMeters: 3000,
    counts: const {'BIKE': 1, 'CAR_4': 1},
    freshUntil: DateTime.now().add(Duration(seconds: staleSnapshot ? -1 : 15)),
    drivers: [
      for (final code in ['BIKE', 'CAR_4'])
        NearbyDriver(
          location: Place(
            id: code,
            address: '',
            latitude: latitude,
            longitude: place.longitude,
          ),
          service: code,
          freshUntil: DateTime.now().add(
            Duration(seconds: staleDriver ? -1 : 30),
          ),
        ),
    ],
  );
  @override
  Future<NearbyAvailability> nearby(Place pickup) async {
    requests.add(pickup);
    if (fail) throw const Failure('HTTP_503', 'Offline');
    return delayed[pickup.id]?.future ?? snapshot(pickup);
  }

  @override
  Stream<void> updates(Place pickup) {
    subscriptions++;
    return signals.stream
        .transform(StreamTransformer.fromHandlers())
        .asBroadcastStream(
          onCancel: (subscription) {
            cancellations++;
            subscription.cancel();
          },
        );
  }
}

Widget app(
  LiveDiscovery repo, {
  String service = 'BIKE',
  Place place = pickup,
}) => ProviderScope(
  overrides: [
    sessionProvider.overrideWith(SignedIn.new),
    bookingDiscoveryRepositoryProvider.overrideWithValue(repo),
  ],
  child: MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: NearbyServicesPanel(pickup: place, service: service),
      ),
    ),
  ),
);

List<Marker> nearbyMarkers(WidgetTester tester) => tester
    .widget<MarkerLayer>(find.byType(MarkerLayer))
    .markers
    .where(
      (m) =>
          m.key is ValueKey<String> &&
          (m.key! as ValueKey<String>).value.startsWith('nearby-'),
    )
    .toList();

Future<void> signal(WidgetTester tester, LiveDiscovery repo) async {
  repo.signals.add(null);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
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
    'live markers move, filter by service and preserve a manually panned camera',
    (tester) async {
      final repo = LiveDiscovery();
      addTearDown(repo.signals.close);
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      expect(nearbyMarkers(tester).single.key, const ValueKey('nearby-BIKE'));
      final camera = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      camera.move(const LatLng(10.78, 106.70), 15);
      repo.latitude = 10.774;
      await signal(tester, repo);
      expect(nearbyMarkers(tester).single.point.latitude, 10.774);
      expect(camera.camera.center, const LatLng(10.78, 106.70));
      await tester.pumpWidget(app(repo, service: 'CAR_4'));
      await tester.pumpAndSettle();
      expect(nearbyMarkers(tester).single.key, const ValueKey('nearby-CAR_4'));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('old driver samples and expired snapshots hide markers', (
    tester,
  ) async {
    final repo = LiveDiscovery();
    addTearDown(repo.signals.close);
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();
    expect(nearbyMarkers(tester), hasLength(1));
    repo.staleDriver = true;
    await signal(tester, repo);
    expect(nearbyMarkers(tester), isEmpty);
    repo.staleDriver = false;
    repo.staleSnapshot = true;
    await signal(tester, repo);
    expect(nearbyMarkers(tester), isEmpty);
    expect(find.textContaining('Thông tin xe đã cũ'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'polling recovers after failure and a burst of hub events is merged',
    (tester) async {
      final repo = LiveDiscovery()..fail = true;
      addTearDown(repo.signals.close);
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đang kết nối lại'), findsOneWidget);
      expect(nearbyMarkers(tester), isEmpty);
      repo.fail = false;
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(nearbyMarkers(tester), hasLength(1));
      final before = repo.requests.length;
      for (var i = 0; i < 20; i++) {
        repo.signals.add(null);
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(repo.requests.length, before + 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('changing pickup discards an old in-flight response', (
    tester,
  ) async {
    final repo = LiveDiscovery();
    addTearDown(repo.signals.close);
    final pending = Completer<NearbyAvailability>();
    repo.delayed[pickup.id] = pending;
    await tester.pumpWidget(app(repo));
    await tester.pump();
    const next = Place(
      id: 'new',
      address: 'Điểm mới',
      latitude: 10.78,
      longitude: 106.71,
    );
    await tester.pumpWidget(app(repo, place: next));
    await tester.pumpAndSettle();
    expect(nearbyMarkers(tester).single.point.longitude, next.longitude);
    pending.complete(repo.snapshot(pickup));
    await tester.pumpAndSettle();
    expect(nearbyMarkers(tester).single.point.longitude, next.longitude);
    expect(repo.cancellations, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'background and disposal stop requests; resuming fetches a new snapshot',
    (tester) async {
      final repo = LiveDiscovery();
      addTearDown(repo.signals.close);
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      final before = repo.requests.length;
      await tester.pump(const Duration(seconds: 6));
      expect(repo.requests.length, before);
      expect(repo.cancellations, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(repo.requests.length, before + 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      final disposed = repo.requests.length;
      await tester.pump(const Duration(seconds: 6));
      expect(repo.requests.length, disposed);
      expect(repo.cancellations, 2);
    },
  );
}
