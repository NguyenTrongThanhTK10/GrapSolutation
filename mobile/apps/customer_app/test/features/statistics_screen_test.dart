import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grap_customer/core/core.dart';
import 'package:grap_customer/core/widgets/app_widgets.dart';
import 'package:grap_customer/features/statistics/statistics_screen.dart';

const appRole = 'Customer';

class Session extends SessionController {
  void changeUser(String id) =>
      state = AsyncData(GrapUser(id: id, name: 'Người dùng', role: appRole));
  @override
  Future<GrapUser?> build() async =>
      const GrapUser(id: 'statistics-user', name: 'Người dùng', role: appRole);
}

StatisticsTotals totals({int amount = 100000, bool empty = false}) =>
    StatisticsTotals(
      totalRides: empty ? 0 : 3,
      completedRides: empty ? 0 : 2,
      canceledRides: empty ? 0 : 1,
      unfulfilledRides: 0,
      grossFare: amount,
      commission: amount ~/ 5,
      entitlement: amount * 4 ~/ 5,
      payable: amount,
      paid: amount ~/ 2,
      outstanding: amount ~/ 2,
    );
RideStatistics report(
  StatisticsPeriod period, {
  int amount = 100000,
  bool empty = false,
}) {
  final t = totals(amount: empty ? 0 : amount, empty: empty);
  return RideStatistics(
    period: period,
    role: appRole,
    granularity: 'day',
    generatedAt: DateTime.utc(2026, 11, 4),
    totals: t,
    buckets: [
      for (
        var d = period.from;
        !d.isAfter(period.to);
        d = d.add(const Duration(days: 1))
      )
        StatisticsBucket(d, t),
    ],
    services: empty ? [] : [ServiceStatistics('BIKE', t)],
  );
}

class FakeStatistics implements StatisticsRepository {
  final calls = <StatisticsPeriod>[];
  bool fail = false, empty = false;
  Completer<RideStatistics>? first, next;
  @override
  Future<RideStatistics> load(StatisticsPeriod period) async {
    calls.add(period);
    if (calls.length == 1 && first != null) return first!.future;
    if (calls.length == 2 && next != null) return next!.future;
    if (fail) throw const Failure('NETWORK_ERROR', 'Không có kết nối kiểm thử');
    return report(period, amount: 20000, empty: empty);
  }
}

Widget app(FakeStatistics repo, {double scale = 1}) => ProviderScope(
  overrides: [
    statisticsRepositoryProvider.overrideWithValue(repo),
    sessionProvider.overrideWith(Session.new),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: grapTheme(),
    locale: const Locale('vi'),
    supportedLocales: const [Locale('vi')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: const RideStatisticsScreen(),
  ),
);
void main() {
  testWidgets(
    'changing periods ignores a delayed previous report and copies only the current CSV',
    (tester) async {
      final repo = FakeStatistics()..first = Completer<RideStatistics>();
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(app(repo));
      await tester.pump();
      await tester.pump();
      final previous = repo.calls.first;
      await tester.tap(find.text('Hôm nay'));
      await tester.pumpAndSettle();
      expect(
        repo.calls.last.fromDate,
        StatisticsPeriod.businessToday().toIso8601String().substring(0, 10),
      );
      repo.first!.complete(report(previous, amount: 9000000));
      await tester.pumpAndSettle();
      final amount = tester
          .widget<Text>(find.byKey(const ValueKey('statistics-amount')))
          .data;
      expect(amount, appRole == 'Driver' ? vnd(16000) : vnd(20000));
      await tester.tap(find.text('Sao chép CSV'));
      await tester.pumpAndSettle();
      expect(clipboard, contains(repo.calls.last.fromDate));
      expect(clipboard, contains('20000'));
      expect(clipboard, isNot(contains('9000000')));
    },
  );
  testWidgets(
    'switching account hides the old report and cannot export its late response',
    (tester) async {
      final repo = FakeStatistics()
        ..first = Completer<RideStatistics>()
        ..next = Completer<RideStatistics>();
      await tester.pumpWidget(app(repo));
      await tester.pump();
      await tester.pump();
      final period = repo.calls.first;
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RideStatisticsScreen)),
      );
      (container.read(sessionProvider.notifier) as Session).changeUser(
        'another-user',
      );
      await tester.pump();
      await tester.pump();
      repo.first!.complete(report(period, amount: 9000000));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('statistics-amount')), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Sao chép CSV'),
            )
            .onPressed,
        isNull,
      );
      repo.next!.complete(report(period, amount: 20000));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('statistics-amount')))
            .data,
        appRole == 'Driver' ? vnd(16000) : vnd(20000),
      );
      expect(repo.calls.length, 2);
    },
  );
  testWidgets(
    'failed report disables export and can be retried without leaving the screen',
    (tester) async {
      final repo = FakeStatistics()..fail = true;
      await tester.pumpWidget(app(repo));
      await tester.pumpAndSettle();
      expect(find.textContaining('Không có kết nối kiểm thử'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Sao chép CSV'),
            )
            .onPressed,
        isNull,
      );
      repo.fail = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('statistics-amount')), findsOneWidget);
      expect(repo.calls.length, 2);
    },
  );
  for (final size in const [Size(320, 640), Size(640, 320)]) {
    testWidgets('empty reports fit $size at 160 percent text scale', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeStatistics()..empty = true;
      await tester.pumpWidget(app(repo, scale: 1.6));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Chưa có chuyến kết thúc'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.scrollUntilVisible(
        find.byType(StatisticsChart),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Theo dịch vụ'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Chưa có dữ liệu dịch vụ trong kỳ.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('preset month and custom date picker retain inclusive dates', (
    tester,
  ) async {
    final repo = FakeStatistics();
    await tester.pumpWidget(app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tháng này'));
    await tester.pumpAndSettle();
    expect(repo.calls.last.from.day, 1);
    await tester.tap(find.text('Tùy chọn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    expect(find.byType(DateRangePickerDialog), findsNothing);
    expect(repo.calls.last.to, StatisticsPeriod.businessToday());
    expect(tester.takeException(), isNull);
  });
}
