import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:grap_customer/core/core.dart';
import 'package:grap_customer/core/data/statistics_repository.dart';

import 'api_client_test.dart' show Adapter, client, jsonResponse, session;

Map<String, Object> totalsJson({int completed = 2, int payable = 100000}) => {
  'totalRides': completed + 1,
  'completedRides': completed,
  'canceledRides': 1,
  'unfulfilledRides': 0,
  'grossFare': payable,
  'commission': 0,
  'entitlement': 0,
  'payable': payable,
  'paid': 40000,
  'outstanding': payable - 40000,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('presets follow Vietnam midnight and calendar month, independent of device timezone', () {
    final before = DateTime.utc(2026, 10, 31, 16, 59);
    final after = DateTime.utc(2026, 10, 31, 17);
    expect(StatisticsPeriod.businessToday(before), DateTime.utc(2026, 10, 31));
    expect(StatisticsPeriod.businessToday(after), DateTime.utc(2026, 11, 1));
    final month = StatisticsPeriod.preset('MONTH', now: after);
    expect(month.fromDate, '2026-11-01');
    expect(month.toDate, '2026-11-01');
    final week = StatisticsPeriod.preset('WEEK', now: after);
    expect(week.fromDate, '2026-10-26');
    expect(
      week,
      StatisticsPeriod(DateTime(2026, 10, 26), DateTime(2026, 11, 1)),
    );
  });
  test('repository sends inclusive calendar dates and maps full server aggregates and zero buckets', () async {
    final c = client(
      Adapter((options, _) async {
        expect(
          options.path,
          '/me/ride-statistics?from=2020-05-02&to=2020-05-03',
        );
        return jsonResponse({
          'from': '2020-05-02',
          'to': '2020-05-03',
          'role': 'Customer',
          'granularity': 'day',
          'generatedAt': '2026-11-04T01:00:00Z',
          'currency': 'VND',
          'timezone': 'Asia/Ho_Chi_Minh',
          'totals': totalsJson(completed: 41, payable: 4500000),
          'buckets': [
            {
              'date': '2020-05-02',
              'totals': totalsJson(completed: 41, payable: 4500000),
            },
            {
              'date': '2020-05-03',
              'totals': totalsJson(completed: 0, payable: 0),
            },
          ],
          'services': [
            {
              'service': 'BIKE',
              'totals': totalsJson(completed: 41, payable: 4500000),
            },
          ],
        });
      }),
    );
    await c.save(session('a'));
    final result = await ApiStatisticsRepository(c)
        .load(StatisticsPeriod(DateTime(2020, 5, 2), DateTime(2020, 5, 3)));
    expect(result.totals.completedRides, 41);
    expect(result.totals.payable, 4500000);
    expect(result.buckets.last.totals.payable, 0);
    expect(result.services.single.service, 'BIKE');
    final csv = result.toCsv();
    expect(csv, contains('4500000'));
    expect(csv, contains('GrapBike'));
    expect(csv, contains('Thời điểm tải (UTC)'));
    final rows = csv.trim().split('\r\n');
    expect(
      rows
          .skip(1)
          .every(
            (row) => row.split(',').length == rows.first.split(',').length,
          ),
      isTrue,
    );
    expect(csv, isNot(contains('Hoa hồng')));
    expect(csv, isNot(contains('customerId')));
  });
  test(
    'invalid or unbounded ranges are rejected before requesting the server',
    () async {
      var calls = 0;
      final repo = ApiStatisticsRepository(
        client(
          Adapter((_, _) async {
            calls++;
            return jsonResponse({});
          }),
        ),
      );
      for (final period in [
        StatisticsPeriod(DateTime(2020, 2, 2), DateTime(2020, 2, 1)),
        StatisticsPeriod(DateTime(2020), DateTime(2021)),
        StatisticsPeriod(DateTime(9999), DateTime(9999, 1, 2)),
      ]) {
        await expectLater(repo.load(period), throwsA(isA<Failure>()));
      }
      expect(calls, 0);
    },
  );
}
