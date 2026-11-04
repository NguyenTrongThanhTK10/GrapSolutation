import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grap_customer/core/core.dart';
import 'package:grap_customer/core/widgets/app_widgets.dart';
import 'package:grap_customer/features/booking/widgets/nearby_services.dart';

import 'booking_ui_test.dart' show SignedIn, pickup;

class Discovery implements BookingDiscoveryRepository {
  int calls = 0;
  bool expired = false, fail = false;
  @override
  Future<NearbyAvailability> nearby(Place pickup) async {
    calls++;
    if (fail) throw const Failure('HTTP_503', 'Chưa kết nối');
    return NearbyAvailability(
      inServiceZone: true,
      radiusMeters: 3000,
      counts: const {'BIKE': 2},
      freshUntil: DateTime.now().add(Duration(seconds: expired ? -1 : 20)),
    );
  }
}

Widget app(Discovery repository) => ProviderScope(
  overrides: [
    sessionProvider.overrideWith(SignedIn.new),
    bookingDiscoveryRepositoryProvider.overrideWithValue(repository),
  ],
  child: MaterialApp(
    theme: grapTheme(),
    home: const Scaffold(body: NearbyServicesPanel(pickup: pickup)),
  ),
);
void main() {
  testWidgets('expired availability hides old counts and refresh is explicit', (
    tester,
  ) async {
    final repo = Discovery()..expired = true;
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();
    expect(find.textContaining('Thông tin xe đã cũ'), findsOneWidget);
    expect(repo.calls, 1);
    repo.expired = false;
    await tester.tap(find.byTooltip('Cập nhật xe gần đây'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 xe'), findsOneWidget);
    expect(repo.calls, 2);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'unavailable discovery is not reported as zero cars and does not retry automatically',
    (tester) async {
      final repo = Discovery()..fail = true;
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Chưa kiểm tra được xe gần đây'),
        findsOneWidget,
      );
      expect(find.textContaining('0 xe'), findsNothing);
      expect(repo.calls, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
