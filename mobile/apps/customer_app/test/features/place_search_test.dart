import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grap_customer/core/core.dart';
import 'package:grap_customer/core/widgets/app_widgets.dart';
import 'package:grap_customer/features/booking/widgets/booking_place_sheet.dart';
import 'package:grap_customer/features/places/presentation/place_picker_screen.dart';

import 'booking_ui_test.dart' show SignedIn, pickup, dropoff;

class SearchRides implements RideRepository {
  final calls = <String>[];
  final pending = <String, Completer<List<Place>>>{};
  @override
  Future<List<Place>> places(String query) async {
    calls.add(query);
    return pending[query]?.future ?? [];
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class Addresses implements JourneyRepository {
  @override
  Future<List<SavedAddress>> addresses() async => [
    const SavedAddress('home', 'Nhà riêng', pickup, '', 1),
  ];
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class Gps implements LocationProvider {
  final Future<PositionEvidence> Function() result;
  Gps(this.result);
  @override
  Future<PositionEvidence> current() => result();
}

Future<void> mount(
  WidgetTester t,
  SearchRides repo, {
  Widget? child,
  Gps? gps,
  double scale = 1,
}) async {
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(SignedIn.new),
        rideRepositoryProvider.overrideWithValue(repo),
        journeyRepositoryProvider.overrideWithValue(Addresses()),
        if (gps != null) locationProvider.overrideWithValue(gps),
      ],
      child: MaterialApp(
        theme: grapTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home:
            child ??
            Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: FilledButton(
                    onPressed: () => showModalBottomSheet<Place>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      showDragHandle: true,
                      builder: (_) => const BookingPlaceSheet(
                        title: 'Chọn điểm đến',
                        places: [pickup, dropoff],
                        recent: [pickup, dropoff],
                      ),
                    ),
                    child: const Text('Mở tìm kiếm'),
                  ),
                ),
              ),
            ),
      ),
    ),
  );
  await t.pumpAndSettle();
  if (child == null) {
    await t.tap(find.text('Mở tìm kiếm'));
    await t.pumpAndSettle();
  }
}

void main() {
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.path,
        );
  });
  testWidgets(
    'saved and recent addresses are deduplicated and can be found without accents',
    (t) async {
      final repo = SearchRides();
      await mount(t, repo);
      expect(find.text('Nhà riêng'), findsOneWidget);
      expect(find.text(pickup.address), findsOneWidget);
      await t.enterText(find.byType(TextField), 'nha rieng');
      await t.pump(const Duration(milliseconds: 350));
      await t.pumpAndSettle();
      expect(find.text('Nhà riêng'), findsOneWidget);
      expect(repo.calls, ['nha rieng']);
      expect(find.text(dropoff.address), findsNothing);
      await t.tap(find.byTooltip('Xóa từ khóa'));
      await t.pumpAndSettle();
      expect(find.text(dropoff.address), findsOneWidget);
      expect(repo.calls.length, 1);
    },
  );
  testWidgets(
    'a slow old query cannot overwrite current results and provider aliases remain selectable',
    (t) async {
      final repo = SearchRides()
        ..pending['old'] = Completer<List<Place>>()
        ..pending['TSN'] = Completer<List<Place>>();
      await mount(t, repo);
      await t.enterText(find.byType(TextField), 'old');
      await t.pump(const Duration(milliseconds: 350));
      await t.enterText(find.byType(TextField), 'TSN');
      await t.pump(const Duration(milliseconds: 350));
      const airport = Place(
        id: 'airport',
        address: 'Sân bay Tân Sơn Nhất',
        latitude: 10.813,
        longitude: 106.652,
      );
      repo.pending['TSN']!.complete([airport]);
      await t.pumpAndSettle();
      expect(find.text(airport.address), findsOneWidget);
      repo.pending['old']!.complete([dropoff]);
      await t.pumpAndSettle();
      expect(find.text(airport.address), findsOneWidget);
      expect(find.text(dropoff.address), findsNothing);
      await t.tap(find.text(airport.address));
      await t.pumpAndSettle();
      expect(find.text('Mở tìm kiếm'), findsOneWidget);
    },
  );
  for (final size in const [Size(320, 640), Size(640, 320)]) {
    testWidgets('search remains usable with keyboard and large text at $size', (
      t,
    ) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      t.view.viewInsets = FakeViewPadding(
        bottom: size.height > 400 ? 240 : 130,
      );
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetViewInsets);
      await mount(t, SearchRides(), scale: 1.6);
      expect(t.takeException(), isNull);
      await t.enterText(find.byType(TextField), 'Landmark');
      await t.pump(const Duration(milliseconds: 350));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'manual pin selection wins over a delayed GPS result and requires a matching description',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      t.view.viewInsets = const FakeViewPadding(bottom: 200);
      t.view.viewPadding = const FakeViewPadding(bottom: 34);
      addTearDown(t.view.resetViewPadding);
      addTearDown(t.view.resetPadding);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetViewInsets);
      final pending = Completer<PositionEvidence>();
      await mount(
        t,
        SearchRides(),
        gps: Gps(() => pending.future),
        child: const PlacePickerScreen(title: 'Điểm đón', locateOnOpen: true),
      );
      t.widget<GrapMap>(find.byType(GrapMap)).onPick!(dropoff);
      await t.pump();
      pending.complete(
        PositionEvidence(
          latitude: pickup.latitude,
          longitude: pickup.longitude,
          accuracy: 10,
          recordedAt: DateTime.now(),
          sequence: 1,
        ),
      );
      await t.pumpAndSettle();
      expect(
        t.widget<GrapMap>(find.byType(GrapMap)).pickup!.latitude,
        dropoff.latitude,
      );
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Xác nhận vị trí'),
            )
            .onPressed,
        isNull,
      );
      expect(
        t
            .getBottomRight(
              find.widgetWithText(FilledButton, 'Xác nhận vị trí'),
            )
            .dy,
        lessThanOrEqualTo(644),
      );
      t.view.viewInsets = const FakeViewPadding();
      t.view.padding = const FakeViewPadding(bottom: 34);
      await t.pumpAndSettle();
      expect(
        t
            .getBottomRight(
              find.widgetWithText(FilledButton, 'Xác nhận vị trí'),
            )
            .dy,
        lessThanOrEqualTo(810),
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}
