import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grap_driver/core/core.dart';
import 'package:grap_driver/core/widgets/grap_map.dart';
import 'package:grap_driver/features/driving/driver_controller.dart';
import 'package:grap_driver/features/driving/driver_screen.dart';

import 'driving_ui_test.dart' show DrivingController, mount, offer, user;

const approved = Availability(
  online: true,
  busy: false,
  offlineAfterRide: false,
  deviceActive: true,
  version: 1,
  reviewStatus: 'APPROVED',
);
const earnings = Earnings(
  completedRides: 24,
  entitlement: 1250000,
  commission: 250000,
  available: 850000,
  pending: 100000,
  held: 50000,
  debt: 250000,
);
RideSnapshot trip(String status) => RideSnapshot(
  id: 'ride',
  code: 'GR-260116',
  status: status,
  service: 'BIKE',
  version: 3,
  pickup: offer().pickup,
  dropoff: const Place(
    id: 'b',
    address: 'Landmark 81, Bình Thạnh',
    latitude: 10.7951,
    longitude: 106.7218,
  ),
  fare: const Fare(payable: 50000, gross: 50000, commission: 10000),
  createdAt: DateTime.now(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    testWidgets(
      'availability and trip actions stay reachable at $size with large text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final controller = DrivingController();
        await mount(
          tester,
          const DriverScreen(user: user),
          controller: controller,
          scale: 1.6,
        );
        final availability = find.byKey(
          const ValueKey('driver-availability-action'),
        );
        expect(availability.hitTestable(), findsOneWidget);
        await tester.tap(availability);
        await tester.pumpAndSettle();
        expect(controller.toggleCalls, 1);
        controller.updateView(
          DriverViewState(availability: approved, ride: trip('ASSIGNED')),
        );
        await tester.pumpAndSettle();
        final action = find.byKey(const ValueKey('driver-trip-action'));
        expect(action.hitTestable(), findsOneWidget);
        await tester.drag(find.byType(ListView).first, const Offset(0, -700));
        await tester.pumpAndSettle();
        expect(action.hitTestable(), findsOneWidget);
        await tester.tap(action);
        expect(controller.arriveCalls, 1);
        controller.updateView(
          DriverViewState(availability: approved, ride: trip('IN_PROGRESS')),
        );
        await tester.pumpAndSettle();
        await tester.tap(action);
        expect(controller.completeCalls, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'home displays the published driver position and exposes GPS recovery',
    (tester) async {
      final position = PositionEvidence(
        latitude: 10.78,
        longitude: 106.70,
        accuracy: 12,
        recordedAt: DateTime.now(),
        sequence: 2,
      );
      final controller = DrivingController(
        initial: DriverViewState(availability: approved, position: position),
      );
      await mount(
        tester,
        const DriverScreen(user: user),
        controller: controller,
      );
      expect(
        tester.widget<GrapMap>(find.byType(GrapMap)).driver?.latitude,
        position.latitude,
      );
      expect(find.text('Vị trí đã cập nhật'), findsOneWidget);
      controller.updateView(
        DriverViewState(
          availability: approved,
          position: position,
          locationError: 'Chưa xác nhận được GPS',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cần cập nhật vị trí'), findsOneWidget);
      expect(find.text('Chưa xác nhận được GPS'), findsOneWidget);
      expect(
        find.widgetWithText(TextButton, 'Cập nhật vị trí'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'wallet amounts stay readable with large text on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final controller = DrivingController(
        initial: const DriverViewState(
          availability: approved,
          earnings: earnings,
        ),
      );
      await mount(
        tester,
        const DriverScreen(user: user),
        controller: controller,
        scale: 1.6,
      );
      await tester.tap(find.text('Thu nhập'));
      await tester.pumpAndSettle();
      expect(find.text('1.250.000 ₫'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Công nợ cần nộp'), 220);
      await tester.ensureVisible(find.text('Công nợ cần nộp'));
      await tester.pumpAndSettle();
      expect(find.text('Công nợ cần nộp').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
