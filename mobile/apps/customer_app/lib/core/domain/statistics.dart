/// Calendar dates in Asia/Ho_Chi_Minh, independent of the device timezone.
class StatisticsPeriod {
  final DateTime from, to;
  StatisticsPeriod(DateTime from, DateTime to)
    : from = DateTime.utc(from.year, from.month, from.day),
      to = DateTime.utc(to.year, to.month, to.day);

  static DateTime businessToday([DateTime? now]) {
    final local = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7));
    return DateTime.utc(local.year, local.month, local.day);
  }

  static StatisticsPeriod preset(String value, {DateTime? now}) {
    final today = businessToday(now);
    return StatisticsPeriod(switch (value) {
      'TODAY' => today,
      'MONTH' => DateTime.utc(today.year, today.month),
      _ => today.subtract(const Duration(days: 6)),
    }, today);
  }

  String get fromDate => from.toIso8601String().substring(0, 10);
  String get toDate => to.toIso8601String().substring(0, 10);
  @override
  bool operator ==(Object other) =>
      other is StatisticsPeriod && from == other.from && to == other.to;
  @override
  int get hashCode => Object.hash(from, to);
}

class StatisticsTotals {
  final int totalRides, completedRides, canceledRides, unfulfilledRides;
  final int grossFare, commission, entitlement, payable, paid, outstanding;
  const StatisticsTotals({
    required this.totalRides,
    required this.completedRides,
    required this.canceledRides,
    required this.unfulfilledRides,
    required this.grossFare,
    required this.commission,
    required this.entitlement,
    required this.payable,
    required this.paid,
    required this.outstanding,
  });
  factory StatisticsTotals.fromJson(Map<String, dynamic> j) => StatisticsTotals(
    totalRides: (j['totalRides'] as num).toInt(),
    completedRides: (j['completedRides'] as num).toInt(),
    canceledRides: (j['canceledRides'] as num).toInt(),
    unfulfilledRides: (j['unfulfilledRides'] as num).toInt(),
    grossFare: (j['grossFare'] as num).toInt(),
    commission: (j['commission'] as num).toInt(),
    entitlement: (j['entitlement'] as num).toInt(),
    payable: (j['payable'] as num).toInt(),
    paid: (j['paid'] as num).toInt(),
    outstanding: (j['outstanding'] as num).toInt(),
  );
}

class StatisticsBucket {
  final DateTime date;
  final StatisticsTotals totals;
  const StatisticsBucket(this.date, this.totals);
}

class ServiceStatistics {
  final String service;
  final StatisticsTotals totals;
  const ServiceStatistics(this.service, this.totals);
}

class RideStatistics {
  final StatisticsPeriod period;
  final String role, granularity;
  final DateTime generatedAt;
  final StatisticsTotals totals;
  final List<StatisticsBucket> buckets;
  final List<ServiceStatistics> services;
  const RideStatistics({
    required this.period,
    required this.role,
    required this.granularity,
    required this.generatedAt,
    required this.totals,
    required this.buckets,
    required this.services,
  });
  bool get driver => role == 'Driver';
  factory RideStatistics.fromJson(Map<String, dynamic> j) => RideStatistics(
    period: StatisticsPeriod(
      DateTime.parse(j['from'] as String),
      DateTime.parse(j['to'] as String),
    ),
    role: j['role'] as String,
    granularity: j['granularity'] as String,
    generatedAt: DateTime.parse(j['generatedAt'] as String),
    totals: StatisticsTotals.fromJson(j['totals'] as Map<String, dynamic>),
    buckets: (j['buckets'] as List)
        .map(
          (e) => StatisticsBucket(
            DateTime.parse(e['date'] as String),
            StatisticsTotals.fromJson(e['totals'] as Map<String, dynamic>),
          ),
        )
        .toList(),
    services: (j['services'] as List)
        .map(
          (e) => ServiceStatistics(
            e['service'] as String,
            StatisticsTotals.fromJson(e['totals'] as Map<String, dynamic>),
          ),
        )
        .toList(),
  );

  /// Aggregate-only CSV: no addresses, phone numbers or ride identifiers.
  String toCsv() {
    String row(List<Object> cells) => cells
        .map((value) => '"${value.toString().replaceAll('"', '""')}"')
        .join(',');
    List<Object> values(String kind, String label, StatisticsTotals t) => [
      kind,
      label,
      period.fromDate,
      period.toDate,
      generatedAt.toUtc().toIso8601String(),
      t.totalRides,
      t.completedRides,
      t.canceledRides,
      t.unfulfilledRides,
      if (driver) ...[t.grossFare, t.commission, t.entitlement],
      t.payable,
      t.paid,
      t.outstanding,
    ];
    return '\uFEFF${[
      row([
        'Loại',
        'Kỳ / dịch vụ',
        'Từ ngày (giờ Việt Nam)',
        'Đến ngày (bao gồm)',
        'Thời điểm tải (UTC)',
        'Chuyến đã kết thúc',
        'Hoàn tất',
        'Đã hủy',
        'Không thành chuyến',
        if (driver) ...['Giá gộp VND', 'Hoa hồng VND', 'Quyền lợi VND'],
        'Phải trả VND',
        'Đã thu VND',
        'Còn lại VND',
      ]),
      row(values('Tổng hợp', 'Toàn kỳ', totals)),
      for (final b in buckets) row(values(granularity == 'month' ? 'Tháng' : 'Ngày', b.date.toIso8601String().substring(0, granularity == 'month' ? 7 : 10), b.totals)),
      for (final s in services) row(values('Dịch vụ', switch (s.service) {
          'BIKE' => 'GrapBike',
          'CAR_4' => 'GrapCar 4 chỗ',
          'CAR_7' => 'GrapCar 7 chỗ',
          _ => 'Dịch vụ khác',
        }, s.totals)),
    ].join('\r\n')}\r\n';
  }
}

abstract interface class StatisticsRepository {
  Future<RideStatistics> load(StatisticsPeriod period);
}
