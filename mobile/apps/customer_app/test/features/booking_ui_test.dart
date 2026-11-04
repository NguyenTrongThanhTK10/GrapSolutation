import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grap_customer/core/core.dart';
import 'package:grap_customer/core/widgets/app_widgets.dart';
import 'package:grap_customer/features/booking/customer_controller.dart';
import 'package:grap_customer/features/booking/customer_screen.dart';
import 'package:grap_customer/features/booking/widgets/booking_action_bar.dart';

const user = GrapUser(id: 'customer', name: 'Ngọc Hà', role: 'Customer');
const pickup = Place(
  id: 'a',
  address: 'Chợ Bến Thành, Quận 1',
  latitude: 10.77,
  longitude: 106.69,
);
const dropoff = Place(
  id: 'b',
  address: 'Landmark 81, Bình Thạnh',
  latitude: 10.79,
  longitude: 106.72,
);
QuoteSnapshot quote({bool expired = false}) => QuoteSnapshot(
  id: 'quote',
  source: 'test',
  fare: const Fare(payable: 50000, gross: 50000, commission: 10000),
  distanceMeters: 5000,
  durationSeconds: 900,
  expiresAt: DateTime.now().toUtc().add(Duration(seconds: expired ? -1 : 120)),
);

class SignedIn extends SessionController {
  @override
  Future<GrapUser?> build() async => user;
}

class BookingController extends CustomerController {
  int quoteCalls = 0, bookCalls = 0;
  String? get destinationId => state.value?.dropoff?.id;
  String? get selectedService => state.value?.service;
  @override
  Future<CustomerState> build() async => const CustomerState(
    places: [pickup, dropoff],
    pickup: pickup,
    dropoff: dropoff,
  );
  @override
  Future<void> refresh({bool? forceSupplemental}) async {}
  @override
  void setForeground(bool active) {}
  @override
  Future<void> quote() async {
    quoteCalls++;
    state = AsyncData(state.value!.copyWith(quote: _newQuote()));
  }

  QuoteSnapshot _newQuote() => QuoteSnapshot(
    id: 'quote',
    source: 'test',
    fare: const Fare(payable: 50000, gross: 50000, commission: 10000),
    distanceMeters: 5000,
    durationSeconds: 900,
    expiresAt: DateTime.now().toUtc().add(const Duration(seconds: 120)),
  );
  @override
  Future<void> book() async {
    bookCalls++;
  }
}

class NoNearby implements BookingDiscoveryRepository {
  @override
  Future<NearbyAvailability> nearby(Place pickup) async => NearbyAvailability(
    inServiceZone: true,
    radiusMeters: 3000,
    counts: const {'BIKE': 0, 'CAR_4': 0, 'CAR_7': 0},
    freshUntil: DateTime.now().add(const Duration(seconds: 20)),
  );
}

class EmptyJourney implements JourneyRepository {
  @override
  Future<List<SavedAddress>> addresses() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> mount(
  WidgetTester tester,
  Widget child, {
  BookingController? controller,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(SignedIn.new),
        pendingOperationsProvider.overrideWith((ref) async => []),
        bookingDiscoveryRepositoryProvider.overrideWithValue(NoNearby()),
        journeyRepositoryProvider.overrideWithValue(EmptyJourney()),
        if (controller != null)
          customerControllerProvider.overrideWith(() => controller),
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
    'booking action remains reachable after scrolling a small screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final controller = BookingController();
      await mount(
        tester,
        const CustomerScreen(user: user),
        controller: controller,
        scale: 1.6,
      );
      expect(find.text('Xem giá chuyến đi').hitTestable(), findsOneWidget);
      await tester.dragFrom(const Offset(10, 250), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('Xem giá chuyến đi').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Xem giá chuyến đi'));
      await tester.pumpAndSettle();
      expect(controller.quoteCalls, 1);
      expect(find.text('Xác nhận đặt xe').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Xác nhận đặt xe'));
      expect(controller.bookCalls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('expired quote requests a fresh quote instead of booking', (
    tester,
  ) async {
    int quoteCalls = 0, bookCalls = 0;
    await mount(
      tester,
      Scaffold(
        bottomNavigationBar: BookingActionBar(
          quote: quote(expired: true),
          busy: false,
          hasRoute: true,
          onQuote: () => quoteCalls++,
          onBook: () => bookCalls++,
        ),
      ),
    );
    await tester.tap(find.text('Lấy báo giá mới'));
    expect(quoteCalls, 1);
    expect(bookCalls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'missing route and an in-flight booking disable the primary action',
    (tester) async {
      await mount(
        tester,
        Scaffold(
          bottomNavigationBar: BookingActionBar(
            busy: false,
            hasRoute: false,
            onQuote: () => fail('No route'),
            onBook: () => fail('No quote'),
          ),
        ),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await mount(
        tester,
        Scaffold(
          bottomNavigationBar: BookingActionBar(
            quote: quote(),
            busy: true,
            hasRoute: true,
            onQuote: () => fail('Busy'),
            onBook: () => fail('Busy'),
          ),
        ),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a suggested destination is selected from the consolidated picker',
    (tester) async {
      final controller = BookingController();
      await mount(
        tester,
        const CustomerScreen(user: user),
        controller: controller,
      );
      await tester.tap(find.text('Điểm đến'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(pickup.address).last);
      await tester.pumpAndSettle();
      expect(controller.destinationId, pickup.id);
      expect(find.text('Địa điểm gợi ý'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('booking actions fit landscape with large text', (tester) async {
    tester.view.physicalSize = const Size(640, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = BookingController();
    await mount(
      tester,
      const CustomerScreen(user: user),
      controller: controller,
      scale: 1.6,
    );
    await tester.tap(find.text('Xem giá chuyến đi'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(FilledButton, 'Xác nhận đặt xe').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'choosing another vehicle clears the previous quote before confirmation',
    (tester) async {
      final controller = BookingController();
      await mount(
        tester,
        const CustomerScreen(user: user),
        controller: controller,
      );
      await tester.tap(find.text('Xem giá chuyến đi'));
      await tester.pumpAndSettle();
      final car = find.text('Ô tô 4 chỗ');
      await tester.ensureVisible(car);
      await tester.pumpAndSettle();
      await tester.tap(car);
      await tester.pumpAndSettle();
      expect(controller.selectedService, 'CAR_4');
      expect(find.text('Xem giá chuyến đi'), findsOneWidget);
      expect(find.text('Xác nhận đặt xe'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
