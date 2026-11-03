import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:grap_driver/core/core.dart';
import 'package:grap_driver/core/widgets/grap_map.dart';

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
  setUpAll(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => Directory.systemTemp.path,
        ),
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
}
