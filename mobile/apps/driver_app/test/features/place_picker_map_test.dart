import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grap_driver/core/core.dart';
import 'package:grap_driver/core/widgets/grap_map.dart';
import 'package:grap_driver/features/places/presentation/place_picker_screen.dart';
import 'package:latlong2/latlong.dart';

const original = Place(
  id: 'initial',
  address: 'Địa chỉ cũ',
  latitude: 10.77,
  longitude: 106.69,
);
const manual = Place(
  id: 'manual',
  address: 'Ghim mới',
  latitude: 10.78,
  longitude: 106.70,
);

class Gps implements LocationProvider {
  final Future<PositionEvidence> Function() result;
  Gps(this.result);
  @override
  Future<PositionEvidence> current() => result();
}

PositionEvidence sample() => PositionEvidence(
  latitude: original.latitude,
  longitude: original.longitude,
  accuracy: 8,
  recordedAt: DateTime.now(),
  sequence: 1,
);

Future<void> mount(WidgetTester tester, Gps gps) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1200);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [locationProvider.overrideWithValue(gps)],
      child: MaterialApp(
        home: const PlacePickerScreen(title: 'Chọn vị trí', initial: original),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.path,
        );
  });

  testWidgets(
    'a manual pin cancels a pending GPS selection and clears the previous address',
    (tester) async {
      final pending = Completer<PositionEvidence>();
      await mount(tester, Gps(() => pending.future));
      await tester.tap(find.text('Sử dụng vị trí thiết bị'));
      await tester.pump();
      tester.widget<GrapMap>(find.byType(GrapMap)).onPick!(manual);
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );

      pending.complete(sample());
      await tester.pumpAndSettle();
      expect(
        tester.widget<GrapMap>(find.byType(GrapMap)).pickup!.latitude,
        manual.latitude,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Xác nhận vị trí'),
            )
            .onPressed,
        isNull,
      );

      await tester.enterText(find.byType(TextField), 'Cổng tòa nhà mới');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Xác nhận vị trí'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a failed old GPS request does not replace a manual selection with an error',
    (tester) async {
      final pending = Completer<PositionEvidence>();
      await mount(tester, Gps(() => pending.future));
      await tester.tap(find.text('Sử dụng vị trí thiết bị'));
      await tester.pump();
      tester.widget<GrapMap>(find.byType(GrapMap)).onPick!(manual);
      await tester.pump();
      pending.completeError(const Failure('GPS_DISABLED', 'Lỗi GPS cũ'));
      await tester.pumpAndSettle();
      expect(find.text('Lỗi GPS cũ'), findsNothing);
      expect(
        tester.widget<GrapMap>(find.byType(GrapMap)).pickup!.latitude,
        manual.latitude,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('requesting the same GPS position recenters after a user pan', (
    tester,
  ) async {
    await mount(tester, Gps(() async => sample()));
    await tester.tap(find.text('Sử dụng vị trí thiết bị'));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    await tester.drag(find.byType(FlutterMap), const Offset(-100, 20));
    await tester.pumpAndSettle();
    expect(controller.camera.center, isNot(const LatLng(10.77, 106.69)));
    await tester.tap(find.text('Sử dụng vị trí thiết bị'));
    await tester.pumpAndSettle();
    expect(controller.camera.center, const LatLng(10.77, 106.69));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
