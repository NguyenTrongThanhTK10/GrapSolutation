import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:grap_customer/core/core.dart';
import 'package:grap_customer/core/widgets/grap_map.dart';

const original = Place(
  id: 'manual',
  address: 'HCM',
  latitude: 10.77,
  longitude: 106.69,
);
const updated = Place(
  id: 'manual',
  address: 'Hà Nội',
  latitude: 21.03,
  longitude: 105.85,
);
Widget map(Place pickup, {Place? dropoff}) => MaterialApp(
  home: Scaffold(
    body: GrapMap(pickup: pickup, dropoff: dropoff),
  ),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory cacheDirectory;
  late BuiltInMapCachingProvider cache;
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => Directory.systemTemp.path,
        );
    // Initialise filesystem work outside the widget test's fake clock so tile
    // requests can actually reach the simulated HTTP client.
    cacheDirectory = await Directory.systemTemp.createTemp('grap-map-test-');
    cache = BuiltInMapCachingProvider.getOrCreateInstance(
      cacheDirectory: cacheDirectory.path,
    );
    await cache.getTile('warm-up');
  });
  tearDownAll(() async {
    await cache.destroy(deleteCache: true);
    await cacheDirectory.delete(recursive: true);
  });
  testWidgets(
    'detailed routes render all bends and fit coordinates beyond the endpoints',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GrapMap(
              pickup: original,
              dropoff: original,
              routePoints: [original, updated, original],
              recordedPoints: [original, updated],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final lines = tester
          .widget<PolylineLayer>(find.byType(PolylineLayer))
          .polylines;
      expect(lines, hasLength(2));
      expect(lines.first.points, hasLength(3));
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      expect(
        controller.camera.visibleBounds.contains(const LatLng(21.03, 105.85)),
        isTrue,
      );
      await tester.pumpWidget(map(original));
      await tester.pumpAndSettle();
      expect(
        controller.camera.center.latitude,
        closeTo(original.latitude, .0001),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'updated GPS coordinates recenter the same map even when the place ID is unchanged',
    (tester) async {
      await tester.pumpWidget(map(original));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      await tester.pumpWidget(map(updated));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController,
        same(controller),
      );
      expect(
        controller.camera.center.latitude,
        closeTo(updated.latitude, .0001),
      );
      expect(
        controller.camera.center.longitude,
        closeTo(updated.longitude, .0001),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'route framing includes both endpoints and can recover after manual panning',
    (tester) async {
      await tester.pumpWidget(map(original, dropoff: updated));
      await tester.pumpAndSettle();
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      expect(
        controller.camera.visibleBounds.contains(const LatLng(10.77, 106.69)),
        isTrue,
      );
      expect(
        controller.camera.visibleBounds.contains(const LatLng(21.03, 105.85)),
        isTrue,
      );
      controller.move(const LatLng(0, 0), 15);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Xem toàn bộ hành trình'));
      await tester.pumpAndSettle();
      expect(
        controller.camera.visibleBounds.contains(const LatLng(10.77, 106.69)),
        isTrue,
      );
      expect(
        controller.camera.visibleBounds.contains(const LatLng(21.03, 105.85)),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'unavailable tiles show a retry action instead of an indefinitely blank map',
    (tester) async {
      await tester.pumpWidget(map(original));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 9));
      expect(find.byTooltip('Thử lại bản đồ'), findsOneWidget);
      await tester.tap(find.byTooltip('Thử lại bản đồ'));
      await tester.pump();
      expect(find.byTooltip('Thử lại bản đồ'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'connection resets keep retry available without image service exceptions',
    (tester) async {
      final clients = <_ResetHttpClient>[];
      tester.binding.imageCache.clear();
      tester.binding.imageCache.clearLiveImages();
      await HttpOverrides.runZoned(
        () async {
          await tester.pumpWidget(map(original));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pumpAndSettle();
          expect(clients.single.requests, greaterThan(0));
          expect(tester.takeException(), isNull);
          await tester.pump(const Duration(seconds: 9));
          expect(find.byTooltip('Thử lại bản đồ'), findsOneWidget);

          final firstClient = clients.single;
          await tester.tap(find.byTooltip('Thử lại bản đồ'));
          await tester.pump();
          expect(find.byTooltip('Thử lại bản đồ'), findsNothing);
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pumpAndSettle();
          expect(firstClient.closed, isTrue);
          expect(clients, hasLength(2));
          expect(clients.last.requests, greaterThan(0));
          expect(tester.takeException(), isNull);
          await tester.pump(const Duration(seconds: 9));
          expect(find.byTooltip('Thử lại bản đồ'), findsOneWidget);
          expect(find.byTooltip('Xem toàn bộ hành trình'), findsOneWidget);
          await tester.pumpWidget(const SizedBox.shrink());
          expect(clients.last.closed, isTrue);
        },
        createHttpClient: (_) {
          final client = _ResetHttpClient();
          clients.add(client);
          return client;
        },
      );
    },
  );
}

class _ResetHttpClient extends Fake implements HttpClient {
  int requests = 0;
  bool closed = false;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    requests++;
    throw const SocketException(
      'Connection reset by peer',
      osError: OSError('Connection reset by peer', 104),
    );
  }

  @override
  void close({bool force = false}) => closed = true;
}
