import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:grap_driver/core/core.dart';
import 'package:grap_driver/core/widgets/app_widgets.dart';

class RideStatisticsScreen extends ConsumerStatefulWidget {
  final StatisticsPeriod? initialPeriod;
  const RideStatisticsScreen({super.key, this.initialPeriod});

  @override
  ConsumerState<RideStatisticsScreen> createState() => _StatisticsState();
}

class _StatisticsState extends ConsumerState<RideStatisticsScreen> {
  late StatisticsPeriod period;
  String preset = 'WEEK';
  final dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    period = widget.initialPeriod ?? StatisticsPeriod.preset('WEEK');
    if (widget.initialPeriod != null) preset = 'CUSTOM';
  }

  Future<void> chooseDates() async {
    final today = StatisticsPeriod.businessToday();
    final chosen = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year, today.month, today.day),
      initialDateRange: DateTimeRange(
        start: DateTime(period.from.year, period.from.month, period.from.day),
        end: DateTime(period.to.year, period.to.month, period.to.day),
      ),
      helpText: 'Chọn tối đa 366 ngày',
      saveText: 'Áp dụng',
    );
    if (!mounted || chosen == null) return;
    final next = StatisticsPeriod(chosen.start, chosen.end);
    if (next.to.difference(next.from).inDays >= 366) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn tối đa 366 ngày.')),
      );
      return;
    }
    setState(() {
      preset = 'CUSTOM';
      period = next;
    });
  }

  Future<void> refresh() async {
    try {
      ref.invalidate(rideStatisticsProvider(period));
      await ref.read(rideStatisticsProvider(period).future);
    } catch (_) {
      /* The provider renders the error and retry action. */
    }
  }

  Future<void> copyCsv(RideStatistics report) async {
    try {
      await Clipboard.setData(ClipboardData(text: report.toCsv()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã sao chép báo cáo CSV. Bạn có thể dán vào Excel hoặc trình soạn thảo.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa sao chép được báo cáo. Vui lòng thử lại.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rideStatisticsProvider(period));
    final report = state.asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo & thống kê')),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(
              'Nhìn lại hành trình',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Chọn kỳ để xem số chuyến và số tiền của bạn.',
              style: TextStyle(color: grapMuted, height: 1.5),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in const {
                  'TODAY': 'Hôm nay',
                  'WEEK': '7 ngày',
                  'MONTH': 'Tháng này',
                }.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: preset == entry.key,
                    onSelected: (_) => setState(() {
                      preset = entry.key;
                      period = StatisticsPeriod.preset(entry.key);
                    }),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.date_range_outlined, size: 18),
                  label: const Text('Tùy chọn'),
                  onPressed: chooseDates,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${dateFormat.format(period.from)} – ${dateFormat.format(period.to)}',
              key: const ValueKey('statistics-period'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: grapInk,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: state.isLoading ? null : refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Làm mới'),
                ),
                OutlinedButton.icon(
                  onPressed: report == null || state.isLoading || state.hasError
                      ? null
                      : () => copyCsv(report),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Sao chép CSV'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            state.when(
              skipLoadingOnRefresh: false,
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GrapNotice(error.toString(), error: true),
                  FilledButton.icon(
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
              data: (report) => _report(report),
            ),
          ],
        ),
      ),
    );
  }

  Widget _report(RideStatistics report) {
    final t = report.totals;
    final money = report.driver ? t.entitlement : t.payable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GrapCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.driver ? 'QUYỀN LỢI TRONG KỲ' : 'CƯỚC CHUYẾN HOÀN TẤT',
                style: const TextStyle(
                  color: grapMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                vnd(money),
                key: const ValueKey('statistics-amount'),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: grapGreen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${t.completedRides} chuyến hoàn tất · ${t.totalRides} chuyến đã kết thúc',
                style: const TextStyle(color: grapMuted, height: 1.5),
              ),
            ],
          ),
        ),
        if (t.totalRides == 0)
          const GrapNotice(
            'Chưa có chuyến kết thúc trong kỳ này. Hãy chọn khoảng ngày khác.',
          ),
        const SizedBox(height: 12),
        _metrics([
          ('Đã hoàn tất', '${t.completedRides} chuyến'),
          ('Đã hủy', '${t.canceledRides} chuyến'),
          ('Không thành chuyến', '${t.unfulfilledRides} chuyến'),
          (
            'Tỷ lệ hoàn tất',
            '${t.totalRides == 0 ? '0' : (t.completedRides * 100 / t.totalRides).toStringAsFixed(1)}%',
          ),
        ]),
        const SizedBox(height: 16),
        GrapCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                report.driver
                    ? 'Quyền lợi & khoản thu'
                    : 'Chi tiêu & thanh toán',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (report.driver) ...[
                _moneyRow('Giá gộp chuyến', t.grossFare),
                _moneyRow('Hoa hồng nền tảng', t.commission),
                _moneyRow('Quyền lợi tài xế', t.entitlement),
                const Divider(),
              ],
              _moneyRow('Cước phải trả', t.payable),
              _moneyRow(
                report.driver ? 'Đã thu từ khách' : 'Đã thanh toán',
                t.paid,
              ),
              _moneyRow(
                report.driver ? 'Khách còn phải trả' : 'Còn phải thanh toán',
                t.outstanding,
              ),
              const SizedBox(height: 8),
              Text(
                report.driver
                    ? 'Quyền lợi tính từ chuyến hoàn tất trong kỳ, không phải số dư có thể rút. Khoản đã thu được cập nhật đến thời điểm tải báo cáo.'
                    : 'Cước tính từ chuyến hoàn tất trong kỳ. Tiền đã thanh toán và còn lại được cập nhật đến thời điểm tải báo cáo.',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: grapMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StatisticsChart(report: report),
        const SizedBox(height: 16),
        GrapCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Theo dịch vụ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              if (report.services.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Chưa có dữ liệu dịch vụ trong kỳ.'),
                ),
              for (final item in report.services)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceLabel(item.service),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          Text(
                            '${item.totals.completedRides}/${item.totals.totalRides} chuyến hoàn tất',
                            style: const TextStyle(color: grapMuted),
                          ),
                          Text(
                            vnd(
                              report.driver
                                  ? item.totals.entitlement
                                  : item.totals.payable,
                            ),
                            style: const TextStyle(
                              color: grapGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Tính theo ngày kết thúc chuyến, giờ Việt Nam (UTC+7). Chuyến đang diễn ra chưa được tính. Tỷ lệ hoàn tất so với tất cả chuyến đã kết thúc, gồm hủy, hết hạn và không tìm được tài xế.',
          style: TextStyle(fontSize: 13, height: 1.6, color: grapMuted),
        ),
        const SizedBox(height: 8),
        Text(
          'Cập nhật ${DateFormat('HH:mm dd/MM/yyyy').format(report.generatedAt.toUtc().add(const Duration(hours: 7)))} · VND',
          style: const TextStyle(fontSize: 12, color: grapMuted),
        ),
      ],
    );
  }

  Widget _moneyRow(String label, int amount) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      runSpacing: 6,
      children: [
        Text(label),
        Text(vnd(amount), style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );

  Widget _metrics(List<(String, String)> values) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth / MediaQuery.textScalerOf(context).scale(1) >=
              340
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final value in values)
            SizedBox(
              width: width,
              child: GrapCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value.$1,
                      style: const TextStyle(color: grapMuted, height: 1.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      value.$2,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: grapInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class StatisticsChart extends StatelessWidget {
  final RideStatistics report;
  const StatisticsChart({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    int value(StatisticsBucket bucket) =>
        report.driver ? bucket.totals.entitlement : bucket.totals.payable;
    final maximum = report.buckets.fold<int>(
      0,
      (previous, bucket) => math.max(previous, value(bucket)),
    );
    final monthly = report.granularity == 'month';
    return GrapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${report.driver ? 'Quyền lợi' : 'Cước chuyến'} theo ${monthly ? 'tháng' : 'ngày'}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Đơn vị: VND · Vuốt ngang để xem thêm, chạm cột để xem số tiền.',
            style: TextStyle(color: grapMuted, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final minimum = monthly
                  ? 88.0
                  : report.buckets.length <= 7
                  ? 44.0
                  : 68.0;
              final width = math.max(
                minimum * MediaQuery.textScalerOf(context).scale(1),
                report.buckets.isEmpty
                    ? minimum
                    : constraints.maxWidth / report.buckets.length,
              );
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  height: 240,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final bucket in report.buckets)
                        SizedBox(
                          width: width,
                          child: Semantics(
                            label:
                                '${DateFormat(monthly ? 'MM/yyyy' : 'dd/MM/yyyy').format(bucket.date)}: ${vnd(value(bucket))}, ${bucket.totals.completedRides} chuyến hoàn tất',
                            child: Tooltip(
                              message:
                                  '${DateFormat('dd/MM/yyyy').format(bucket.date)} · ${vnd(value(bucket))}',
                              triggerMode: TooltipTriggerMode.tap,
                              child: ExcludeSemantics(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    SizedBox(
                                      height: 36,
                                      child: Center(
                                        child: Text(
                                          NumberFormat.compact(locale: 'vi')
                                              .format(value(bucket)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: grapMuted,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: 132,
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Container(
                                          width: 26,
                                          height:
                                              maximum == 0 || value(bucket) == 0
                                              ? 4
                                              : math.max(
                                                  4,
                                                  126 * value(bucket) / maximum,
                                                ),
                                          decoration: BoxDecoration(
                                            color: value(bucket) == 0
                                                ? const Color(0xffe4eae6)
                                                : grapGreen,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      DateFormat(monthly ? 'MM/yy' : 'dd/MM')
                                          .format(bucket.date),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: grapMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
