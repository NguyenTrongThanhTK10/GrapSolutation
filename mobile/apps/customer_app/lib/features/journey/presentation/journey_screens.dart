import 'package:grap_customer/features/places/presentation/place_picker_screen.dart';
import 'package:grap_customer/features/account/presentation/account_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grap_customer/core/core.dart';
import 'package:grap_customer/core/widgets/app_widgets.dart';
import 'ride_journey_map.dart';

String journeyDate(DateTime at) => at.toLocal().toString().substring(0, 16);

class GrapHistoryPanel extends ConsumerStatefulWidget {
  final ValueChanged<RideSnapshot>? onRebook;
  const GrapHistoryPanel({super.key, this.onRebook});
  @override
  ConsumerState<GrapHistoryPanel> createState() => _HistoryState();
}

class _HistoryState extends ConsumerState<GrapHistoryPanel> {
  final items = <RideSnapshot>[];
  String? status, cursor, error;
  DateTimeRange? range;
  bool busy = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    Future.microtask(() => load(reset: true));
  }

  Future<void> load({bool reset = false}) async {
    if (busy && !reset) return;
    final revision = ++generation;
    setState(() {
      busy = true;
      error = null;
      if (reset) {
        items.clear();
        cursor = null;
      }
    });
    try {
      final result = await ref
          .read(journeyRepositoryProvider)
          .history(
            status: status,
            from: range?.start,
            to: range == null
                ? null
                : DateTime(
                    range!.end.year,
                    range!.end.month,
                    range!.end.day + 1,
                  ),
            cursor: cursor,
          );
      if (!mounted || revision != generation) return;
      setState(() {
        final known = items.map((r) => r.id).toSet();
        items.addAll(result.items.where((r) => known.add(r.id)));
        cursor = result.nextCursor;
      });
    } catch (e) {
      if (mounted && revision == generation) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted && revision == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (previous, next) {
      if (previous?.value?.id != next.value?.id) load(reset: true);
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Lịch sử hành trình',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 18),
        DropdownButtonFormField<String>(
          initialValue: status ?? 'ALL',
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Trạng thái'),
          items: [
            const DropdownMenuItem(
              value: 'ALL',
              child: Text('Tất cả hành trình'),
            ),
            for (final s in [
              'ACTIVE',
              'COMPLETED',
              'CANCELED',
              'NO_DRIVER',
              'EXPIRED',
            ])
              DropdownMenuItem(
                value: s,
                child: Text(s == 'ACTIVE' ? 'Đang diễn ra' : stateLabel(s)),
              ),
          ],
          onChanged: (s) {
            status = s == 'ALL' ? null : s;
            load(reset: true);
          },
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(
                range == null
                    ? 'Lọc theo ngày'
                    : '${journeyDate(range!.start).substring(0, 10)} → ${journeyDate(range!.end).substring(0, 10)}',
              ),
              onPressed: () async {
                final r = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: range,
                );
                if (r != null && mounted) {
                  range = r;
                  load(reset: true);
                }
              },
            ),
            if (range != null)
              TextButton(
                onPressed: () {
                  range = null;
                  load(reset: true);
                },
                child: const Text('Bỏ lọc ngày'),
              ),
            IconButton(
              tooltip: 'Làm mới lịch sử',
              onPressed: () => load(reset: true),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (error != null) ...[
          GrapNotice(error!, error: true),
          TextButton(onPressed: () => load(), child: const Text('Thử lại')),
        ],
        if (!busy && error == null && items.isEmpty)
          const GrapNotice('Không có hành trình phù hợp với bộ lọc.'),
        for (final ride in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GrapCard(
              padding: const EdgeInsets.all(4),
              child: RideHistoryTile(
                ride,
                onTap: () async {
                  final route = await Navigator.push<RideSnapshot>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RideReceiptScreen(
                        rideId: ride.id,
                        allowRebook: widget.onRebook != null,
                      ),
                    ),
                  );
                  if (route != null && mounted) widget.onRebook?.call(route);
                },
              ),
            ),
          ),
        if (busy)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: CircularProgressIndicator(),
            ),
          ),
        if (cursor != null && !busy)
          OutlinedButton(
            onPressed: () => load(),
            child: const Text('Tải thêm hành trình'),
          ),
      ],
    );
  }
}

class JourneyHistoryScreen extends StatelessWidget {
  const JourneyHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lịch sử hành trình')),
    body: const SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: GrapHistoryPanel(),
    ),
  );
}

class RideReceiptScreen extends ConsumerWidget {
  final String rideId;
  final bool allowRebook;
  const RideReceiptScreen({
    super.key,
    required this.rideId,
    this.allowRebook = false,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text('Chi tiết hành trình'),
      actions: [
        IconButton(
          tooltip: 'Làm mới',
          onPressed: () => ref.invalidate(receiptProvider(rideId)),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ref
        .watch(receiptProvider(rideId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GrapNotice(e.toString(), error: true),
                TextButton(
                  onPressed: () => ref.invalidate(receiptProvider(rideId)),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
          data: (d) {
            final r = d.ride, f = r.fare;
            return ListView(
              padding: const EdgeInsets.all(22),
              children: [
                RideJourneyMap(ride: r),
                const SizedBox(height: 18),
                GrapCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        r.code,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      GrapNotice(
                        '${stateLabel(r.status)} · ${serviceLabel(r.service)}',
                      ),
                      Text(journeyDate(r.createdAt)),
                      const Divider(),
                      Text('Điểm đón: ${r.pickup.address}'),
                      const SizedBox(height: 12),
                      Text('Điểm đến: ${r.dropoff.address}'),
                      if (r.driver != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Tài xế ${r.driver!.name} · ${r.driver!.vehicle} · ${r.driver!.plate}',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                GrapCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Chi tiết cước',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _money('Cước mở cửa', f.base),
                      _money('Cước quãng đường', f.distance),
                      _money('Cước thời gian', f.duration),
                      _money('Phí dịch vụ', f.serviceFee),
                      if (f.gross >
                          f.base + f.distance + f.duration + f.serviceFee)
                        _money(
                          'Điều chỉnh cước tối thiểu',
                          f.gross -
                              f.base -
                              f.distance -
                              f.duration -
                              f.serviceFee,
                        ),
                      if (f.discount != 0) _money('Giảm giá', -f.discount),
                      if (f.extras != 0) _money('Phụ phí đã duyệt', f.extras),
                      if (f.tax != 0) _money('Thuế trong cước', f.tax),
                      const Divider(),
                      _money('Cước báo giá', f.payable),
                      if (r.payment != null) ...[
                        _money('Nghĩa vụ thanh toán', r.payment!.payable),
                        _money('Đã thu tiền mặt', r.payment!.paid),
                        _money('Còn phải trả', r.payment!.remaining),
                      ] else
                        Text(
                          r.active
                              ? 'Thanh toán được xác lập sau khi hoàn tất chuyến.'
                              : 'Chuyến này không phát sinh nghĩa vụ thanh toán.',
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        'Bản tóm tắt hành trình trong ứng dụng. Đây không phải hóa đơn thuế.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                GrapCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Nhật ký hành trình',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (d.events.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Chưa có sự kiện.'),
                        ),
                      for (final e in d.events)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.check_circle_outline,
                            color: grapGreen,
                          ),
                          title: Text(
                            _eventLabel(e.type),
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(journeyDate(e.at)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (d.stars != null)
                  GrapNotice(
                    'Đánh giá của bạn: ${d.stars}/5 sao${d.comment.isEmpty ? '' : ' · ${d.comment}'}',
                  ),
                if (d.canReview) ...[
                  Text(
                    'Có thể gửi hoặc sửa đánh giá đến ${journeyDate(d.editableUntil!)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.star_outline),
                    label: Text(
                      d.stars == null ? 'Đánh giá chuyến đi' : 'Sửa đánh giá',
                    ),
                    onPressed: () async {
                      final result = await showDialog<bool>(
                        context: context,
                        builder: (_) => _ReviewDialog(receipt: d),
                      );
                      if (result == true) {
                        ref.invalidate(receiptProvider(rideId));
                      }
                    },
                  ),
                ] else if (r.status == 'COMPLETED')
                  const GrapNotice(
                    'Đã hết thời hạn 24 giờ để đánh giá hoặc chỉnh sửa.',
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.headset_mic_outlined),
                  label: const Text('Hỗ trợ về chuyến này'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => CreateTicketScreen(rideId: r.id),
                    ),
                  ),
                ),
                if (allowRebook && !r.active)
                  TextButton.icon(
                    icon: const Icon(Icons.repeat),
                    label: const Text('Đặt lại tuyến này'),
                    onPressed: () => Navigator.pop(context, r),
                  ),
              ],
            );
          },
        ),
  );
  Widget _money(String label, int value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Text(vnd(value), style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

String _eventLabel(String value) =>
    const {
      'ride.created': 'Đã tạo chuyến',
      'ride.assigned': 'Đã nhận tài xế',
      'ride.driver_arrived': 'Tài xế đã đến',
      'ride.started': 'Đã bắt đầu',
      'ride.completed': 'Đã hoàn tất',
      'ride.canceled': 'Đã hủy',
      'ride.no_driver': 'Không tìm được tài xế',
      'ride.expired': 'Hết thời gian tìm xe',
      'arrive': 'Tài xế đã đến điểm đón',
      'start': 'Đã bắt đầu hành trình',
      'complete': 'Đã hoàn tất hành trình',
      'cancel': 'Đã hủy chuyến',
      'no-show': 'Khách không có mặt tại điểm đón',
      'release': 'Tài xế đã trả chuyến',
      'reassign': 'Đã điều phối lại tài xế',
    }[value] ??
    value;

class _ReviewDialog extends ConsumerStatefulWidget {
  final RideReceipt receipt;
  const _ReviewDialog({required this.receipt});
  @override
  ConsumerState<_ReviewDialog> createState() => _ReviewState();
}

class _ReviewState extends ConsumerState<_ReviewDialog> {
  late int stars = widget.receipt.stars ?? 5;
  late final comment = TextEditingController(text: widget.receipt.comment);
  bool busy = false;
  String? error;
  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Trải nghiệm của bạn'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i sao',
                  onPressed: busy ? null : () => setState(() => stars = i),
                  icon: Icon(
                    i <= stars ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                ),
            ],
          ),
          TextField(
            controller: comment,
            maxLength: 1000,
            maxLines: 3,
            enabled: !busy,
            decoration: const InputDecoration(
              labelText: 'Nhận xét (không bắt buộc)',
            ),
          ),
          if (error != null) GrapNotice(error!, error: true),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                setState(() {
                  busy = true;
                  error = null;
                });
                try {
                  await ref
                      .read(rideRepositoryProvider)
                      .rate(widget.receipt.ride, stars, comment.text.trim());
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (mounted) setState(() => error = e.toString());
                } finally {
                  if (mounted) setState(() => busy = false);
                }
              },
        child: Text(busy ? 'Đang gửi…' : 'Gửi đánh giá'),
      ),
    ],
  );
}

class SavedPlacesScreen extends ConsumerWidget {
  final bool select;
  const SavedPlacesScreen({super.key, this.select = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: Text(select ? 'Chọn địa chỉ đã lưu' : 'Địa chỉ của bạn'),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(context, ref),
      icon: const Icon(Icons.add_location_alt_outlined),
      label: const Text('Thêm địa chỉ'),
    ),
    body: ref
        .watch(savedAddressesProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GrapNotice(e.toString(), error: true),
                TextButton(
                  onPressed: () => ref.invalidate(savedAddressesProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
          data: (items) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              const GrapNotice(
                'Lưu tối đa 20 địa chỉ. Tên địa chỉ cần khác nhau; vị trí được chọn trên bản đồ.',
              ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Chưa có địa chỉ. Thêm nhà, công ty hoặc nơi bạn thường đến.',
                  ),
                ),
              for (final a in items)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: GrapCard(
                    padding: const EdgeInsets.all(5),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.bookmark_outline,
                            color: grapGreen,
                          ),
                          title: Text(a.label),
                          subtitle: Text(
                            '${a.point.address}${a.note.isEmpty ? '' : '\n${a.note}'}',
                          ),
                          onTap: select
                              ? () => Navigator.pop(context, a.point)
                              : () => _edit(context, ref, a),
                        ),
                        if (!select)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => _edit(context, ref, a),
                                child: const Text('Sửa'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  if (await confirmRemoval(
                                        context,
                                        'Xóa địa chỉ ${a.label}?',
                                      ) !=
                                      true) {
                                    return;
                                  }
                                  try {
                                    await ref
                                        .read(journeyRepositoryProvider)
                                        .deleteAddress(a);
                                    ref.invalidate(savedAddressesProvider);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text(e.toString())),
                                      );
                                    }
                                    ref.invalidate(savedAddressesProvider);
                                  }
                                },
                                child: const Text('Xóa'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
  );
  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    SavedAddress? address,
  ]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _AddressEditor(address: address)),
    );
    if (result == true) ref.invalidate(savedAddressesProvider);
  }
}

class _AddressEditor extends ConsumerStatefulWidget {
  final SavedAddress? address;
  const _AddressEditor({this.address});
  @override
  ConsumerState<_AddressEditor> createState() => _AddressState();
}

class _AddressState extends ConsumerState<_AddressEditor> {
  late final label = TextEditingController(text: widget.address?.label ?? ''),
      note = TextEditingController(text: widget.address?.note ?? '');
  late Place? point = widget.address?.point;
  bool busy = false;
  String? error;
  bool conflict = false;
  @override
  void dispose() {
    label.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lưu địa chỉ')),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        TextField(
          controller: label,
          maxLength: 60,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: 'Tên gợi nhớ: Nhà, Công ty…',
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          icon: const Icon(Icons.map_outlined),
          label: Text(point?.address ?? 'Chọn vị trí trên bản đồ'),
          onPressed: busy
              ? null
              : () async {
                  final p = await Navigator.push<Place>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlacePickerScreen(
                        initial: point,
                        title: 'Vị trí địa chỉ',
                      ),
                    ),
                  );
                  if (p != null && mounted) setState(() => point = p);
                },
        ),
        const SizedBox(height: 14),
        TextField(
          controller: note,
          maxLength: 500,
          maxLines: 3,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: 'Ghi chú (không bắt buộc)',
          ),
        ),
        if (error != null) GrapNotice(error!, error: true),
        if (conflict)
          GrapConflictNotice(
            onReload: () {
              ref.invalidate(savedAddressesProvider);
              Navigator.pop(context, true);
            },
          ),
        FilledButton(
          onPressed: busy || conflict
              ? null
              : () async {
                  if (point == null || label.text.trim().isEmpty) {
                    setState(() => error = 'Nhập tên và chọn vị trí để lưu.');
                    return;
                  }
                  setState(() {
                    busy = true;
                    error = null;
                  });
                  try {
                    await ref
                        .read(journeyRepositoryProvider)
                        .saveAddress(
                          label.text,
                          point!,
                          note.text,
                          current: widget.address,
                        );
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (e) {
                    if (mounted) {
                      setState(() {
                        error = e.toString();
                        conflict = e is Failure && e.code == 'VERSION_CONFLICT';
                      });
                    }
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: Text(busy ? 'Đang lưu…' : 'Lưu địa chỉ'),
        ),
      ],
    ),
  );
}
