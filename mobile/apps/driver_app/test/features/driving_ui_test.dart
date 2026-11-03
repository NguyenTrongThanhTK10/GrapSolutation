import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grap_driver/core/core.dart';
import 'package:grap_driver/core/widgets/app_widgets.dart';
import 'package:grap_driver/features/driving/driver_controller.dart';
import 'package:grap_driver/features/driving/driver_screen.dart';
import 'package:grap_driver/features/driving/widgets/driver_offer_bar.dart';

const user = GrapUser(id: 'driver', name: 'Văn Hùng', role: 'Driver');
DriverOffer offer({bool expired = false}) => DriverOffer(
  id: 'offer',
  rideId: 'ride',
  service: 'BIKE',
  version: 1,
  entitlement: 40000,
  payable: 50000,
  expiresAt: DateTime.now().toUtc().add(Duration(seconds: expired ? -1 : 120)),
  pickup: const Place(
    id: 'a',
    address: 'Chợ Bến Thành, Quận 1',
    latitude: 10.77,
    longitude: 106.69,
  ),
);

class SignedIn extends SessionController {
  @override
  Future<GrapUser?> build() async => user;
}

class History extends Fake implements JourneyRepository {
  @override
  Future<RidePage> history({
    String? status,
    DateTime? from,
    DateTime? to,
    String? cursor,
  }) async => const RidePage([], null);
}

class DrivingController extends DriverController {
  int acceptCalls = 0, toggleCalls = 0;
  @override
  Future<DriverViewState> build() async => const DriverViewState(
    availability: Availability(
      online: false,
      busy: false,
      offlineAfterRide: false,
      deviceActive: true,
      version: 1,
      reviewStatus: 'APPROVED',
    ),
  );
  void receive(DriverOffer offer) =>
      state = AsyncData(state.value!.copyWith(offer: offer));
  @override
  Future<void> refresh({bool? forceSupplemental}) async {}
  @override
  void setForeground(bool active) {}
  @override
  Future<void> toggle(bool online) async {
    toggleCalls++;
    state = AsyncData(
      state.value!.copyWith(
        availability: Availability(
          online: online,
          busy: false,
          offlineAfterRide: false,
          deviceActive: true,
          version: toggleCalls + 1,
          reviewStatus: 'APPROVED',
        ),
      ),
    );
  }

  @override
  Future<void> accept() async {
    acceptCalls++;
  }
}

Future<void> mount(
  WidgetTester tester,
  Widget child, {
  DrivingController? controller,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(SignedIn.new),
        pendingOperationsProvider.overrideWith((ref) async => []),
        journeyRepositoryProvider.overrideWithValue(History()),
        if (controller != null)
          driverControllerProvider.overrideWith(() => controller),
      ],
      child: MaterialApp(
        theme: grapTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: child,
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
          (call) async => Directory.systemTemp.path,
        );
  });
  testWidgets(
    'an incoming offer is actionable from another tab with large text on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
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
      await tester.tap(find.text('Thu nhập'));
      await tester.pumpAndSettle();
      controller.receive(offer());
      await tester.pumpAndSettle();
      expect(find.text('Bạn nhận 40.000 ₫'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Nhận chuyến').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Nhận chuyến'));
      expect(controller.acceptCalls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'an expired offer cannot be accepted and can still be dismissed',
    (tester) async {
      int rejected = 0;
      await mount(
        tester,
        Scaffold(
          bottomNavigationBar: DriverOfferBar(
            offer: offer(expired: true),
            busy: false,
            onAccept: () => fail('Expired'),
            onReject: () => rejected++,
          ),
        ),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.text('Đã hết hạn'), findsOneWidget);
      await tester.tap(find.text('Bỏ qua'));
      expect(rejected, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('an in-flight acceptance disables both offer actions', (
    tester,
  ) async {
    await mount(
      tester,
      Scaffold(
        bottomNavigationBar: DriverOfferBar(
          offer: offer(),
          busy: true,
          onAccept: () => fail('Busy'),
          onReject: () => fail('Busy'),
        ),
      ),
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('offer actions fit landscape with large text', (tester) async {
    tester.view.physicalSize = const Size(640, 320);
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
    controller.receive(offer());
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(FilledButton, 'Nhận chuyến').hitTestable(),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextButton, 'Bỏ qua').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'map home toggles approved driver availability through the main action',
    (tester) async {
      final controller = DrivingController();
      await mount(
        tester,
        const DriverScreen(user: user),
        controller: controller,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Bật nhận chuyến'));
      await tester.pumpAndSettle();
      expect(controller.toggleCalls, 1);
      expect(find.text('Đang nhận chuyến'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Tạm ngừng nhận chuyến'),
      );
      await tester.pumpAndSettle();
      expect(controller.toggleCalls, 2);
      expect(find.text('Bạn đang ngoại tuyến'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
