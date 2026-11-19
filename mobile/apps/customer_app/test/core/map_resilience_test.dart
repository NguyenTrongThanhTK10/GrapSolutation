import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:grap_customer/core/core.dart';
import 'package:grap_customer/core/widgets/grap_map.dart';

import '../support/tile_http_client.dart';

const original = Place(
  id: 'gps',
  address: 'Vị trí',
  latitude: 10.77,
  longitude: 106.69,
);
const updated = Place(
  id: 'gps',
  address: 'Vị trí mới',
  latitude: 10.78,
  longitude: 106.70,
);

Widget map({Place? pickup = original, Place? driver, int revision = 0}) =>
    MaterialApp(
      home: Scaffold(
        body: GrapMap(pickup: pickup, driver: driver, cameraRevision: revision),
      ),
    );

MapController camera(WidgetTester tester) =>
    tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;

Future<void> finishTiles(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory cacheDirectory;
  late BuiltInMapCachingProvider cache;
  late Uint8List bytes;
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.path,
        );
    cacheDirectory = await Directory.systemTemp.createTemp(
      'grap-map-resilience-',
    );
    cache = BuiltInMapCachingProvider.getOrCreateInstance(
      cacheDirectory: cacheDirectory.path,
    );
    await cache.getTile('warm-up');
    bytes = await tileBytes();
  });
  tearDownAll(() async {
    await cache.destroy(deleteCache: true);
    await cacheDirectory.delete(recursive: true);
  });
  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  testWidgets(
    'live GPS does not interrupt a user drag; recenter resumes following',
    (tester) async {
      await tester.pumpWidget(map(pickup: null, driver: original));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(FlutterMap), const Offset(-100, 40));
      await tester.pumpAndSettle();
      final panned = camera(tester).camera.center;
      expect(panned, isNot(const LatLng(10.77, 106.69)));

      await tester.pumpWidget(map(pickup: null, driver: updated));
      await tester.pumpAndSettle();
      expect(camera(tester).camera.center, panned);
      expect(
        tester
            .widget<MarkerLayer>(find.byType(MarkerLayer))
            .markers
            .single
            .point,
        const LatLng(10.78, 106.70),
      );

      await tester.pumpWidget(map(pickup: null, driver: updated, revision: 1));
      await tester.pumpAndSettle();
      expect(camera(tester).camera.center, const LatLng(10.78, 106.70));
      await tester.pumpWidget(map(pickup: null, driver: original, revision: 1));
      await tester.pumpAndSettle();
      expect(camera(tester).camera.center, const LatLng(10.77, 106.69));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('choosing a pin preserves the zoom used to inspect the street', (
    tester,
  ) async {
    var selected = original;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => GrapMap(
              pickup: selected,
              onPick: (place) => setState(() => selected = place),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    camera(tester).move(const LatLng(10.77, 106.69), 18);
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getTopLeft(find.byType(FlutterMap)) + const Offset(80, 100),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(selected.latitude, isNot(original.latitude));
    expect(camera(tester).camera.zoom, 18);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('invalid GPS cannot crash projection or hide the usable pickup', (
    tester,
  ) async {
    await tester.pumpWidget(
      map(
        driver: const Place(
          id: 'invalid',
          address: '',
          latitude: double.nan,
          longitude: double.infinity,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(camera(tester).camera.center, const LatLng(10.77, 106.69));
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      hasLength(1),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'a refreshed but unchanged route preserves camera position and zoom',
    (tester) async {
      Widget routeMap() => MaterialApp(
        home: Scaffold(
          body: GrapMap(
            pickup: original,
            dropoff: updated,
            routePoints: [original, updated],
            recordedPoints: [original, updated],
          ),
        ),
      );
      await tester.pumpWidget(routeMap());
      await tester.pumpAndSettle();
      camera(tester).move(const LatLng(10.79, 106.72), 17);
      await tester.pumpAndSettle();
      await tester.pumpWidget(routeMap());
      await tester.pumpAndSettle();
      expect(camera(tester).camera.center, const LatLng(10.79, 106.72));
      expect(camera(tester).camera.zoom, 17);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a new unavailable viewport shows retry and recovers when the network returns',
    (tester) async {
      var offline = false;
      final clients = <TileHttpClient>[];
      await HttpOverrides.runZoned(
        () async {
          await tester.pumpWidget(map());
          await finishTiles(tester);
          expect(clients.single.requests, greaterThan(0));
          await tester.pump(const Duration(seconds: 9));
          expect(find.byTooltip('Thử lại bản đồ'), findsNothing);

          offline = true;
          camera(tester).move(const LatLng(21.03, 105.85), 15);
          await tester.pump();
          await finishTiles(tester);
          await tester.pump(const Duration(seconds: 9));
          expect(find.byTooltip('Thử lại bản đồ'), findsOneWidget);
          expect(tester.takeException(), isNull);

          offline = false;
          await tester.tap(find.byTooltip('Thử lại bản đồ'));
          await tester.pump();
          await finishTiles(tester);
          expect(clients, hasLength(2));
          expect(clients.first.closed, isTrue);
          expect(clients.last.requests, greaterThan(0));
          await tester.pump(const Duration(seconds: 9));
          expect(find.byTooltip('Thử lại bản đồ'), findsNothing);
          expect(camera(tester).camera.center, const LatLng(21.03, 105.85));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          expect(clients.last.closed, isTrue);
        },
        createHttpClient: (_) {
          final client = TileHttpClient(bytes, fails: (_) => offline);
          clients.add(client);
          return client;
        },
      );
    },
  );

  testWidgets(
    'one loaded tile does not conceal failures in the rest of the viewport',
    (tester) async {
      await HttpOverrides.runZoned(
        () async {
          await tester.pumpWidget(map());
          await finishTiles(tester);
          await tester.pump(const Duration(seconds: 9));
          expect(
            find.text('Một phần bản đồ chưa tải được. Hãy thử lại.'),
            findsOneWidget,
          );
          expect(find.byTooltip('Thử lại bản đồ'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        createHttpClient: (_) =>
            TileHttpClient(bytes, fails: (request) => request > 1),
      );
    },
  );
}
