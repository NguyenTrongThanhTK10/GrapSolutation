import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grap_driver/core/core.dart';
import 'package:grap_driver/core/widgets/app_widgets.dart';

import '../driver_controller.dart';

class DriverMapHome extends ConsumerStatefulWidget {
  final DriverViewState view;
  final Future<void> Function(bool online) onToggle;
  final VoidCallback onEarnings, onOnboarding;
  final ValueChanged<Place> onChoosePlace;
  final Future<void> Function() onPublish, onRefresh;
  const DriverMapHome({
    super.key,
    required this.view,
    required this.onToggle,
    required this.onEarnings,
    required this.onOnboarding,
    required this.onChoosePlace,
    required this.onPublish,
    required this.onRefresh,
  });

  @override
  ConsumerState<DriverMapHome> createState() => _DriverMapHomeState();
}

class _DriverMapHomeState extends ConsumerState<DriverMapHome> {
  Place? devicePosition;
  bool locating = false;

  Future<void> _locate() async {
    setState(() => locating = true);
    try {
      final position = await ref.read(locationProvider).current();
      if (mounted) {
        setState(
          () => devicePosition = Place(
            id: 'device',
            address: 'Vị trí của bạn',
            latitude: position.latitude,
            longitude: position.longitude,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  void _demoPlaces() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .55,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            const Text(
              'Vị trí thử nghiệm',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const GrapNotice(
              'Chỉ dùng trong chế độ phát triển. Đây không phải vị trí GPS thực tế.',
            ),
            for (final place in widget.view.places)
              ListTile(
                title: Text(place.address),
                leading: const Icon(Icons.place_outlined),
                onTap: () {
                  widget.onChoosePlace(place);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final online = view.availability?.online == true;
    final approved = view.availability?.reviewStatus == 'APPROVED';
    final showIncome = MediaQuery.textScalerOf(context).scale(14) <= 20;
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Positioned.fill(
            child: GrapMap(
              pickup:
                  view.offer?.pickup ?? devicePosition ?? view.developmentPlace,
              height: constraints.maxHeight,
              borderRadius: 0,
              showControls: false,
              showAttribution: false,
            ),
          ),
          if (constraints.maxHeight > 360 && showIncome)
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                elevation: 3,
                shadowColor: const Color(0x1a000000),
                child: ListTile(
                  onTap: widget.onEarnings,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  leading: const GrapIconBadge(
                    Icons.account_balance_wallet_outlined,
                    size: 44,
                  ),
                  title: const Text(
                    'Thu nhập từ chuyến',
                    style: TextStyle(fontSize: 14, color: grapMuted),
                  ),
                  subtitle: Text(
                    view.earnings == null
                        ? 'Xem bảng thu nhập'
                        : vnd(view.earnings!.entitlement),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: grapInk,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ),
          Positioned(
            top: constraints.maxHeight > 360 && showIncome ? 112 : 12,
            right: 20,
            child: IconButton.filledTonal(
              tooltip: 'Vị trí của tôi',
              onPressed: locating ? null : _locate,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: grapInk,
              ),
              icon: locating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
          Positioned(
            top: constraints.maxHeight > 360 && showIncome ? 112 : 12,
            left: 20,
            child: IconButton.filledTonal(
              tooltip: 'Làm mới trạng thái',
              onPressed: view.busy ? null : widget.onRefresh,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: grapInk,
              ),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          if (view.offer == null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Material(
                color: Colors.white,
                elevation: 8,
                shadowColor: const Color(0x22000000),
                borderRadius: BorderRadius.circular(26),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * .65,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: online
                                    ? grapBrand
                                    : const Color(0xff87948c),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                online
                                    ? 'Đang nhận chuyến'
                                    : 'Bạn đang ngoại tuyến',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: grapMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          !approved
                              ? 'Cùng hoàn thiện hồ sơ'
                              : online
                              ? 'Chủ động từng hành trình'
                              : 'Sẵn sàng cho chuyến mới?',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: grapInk,
                            letterSpacing: -.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          !approved
                              ? 'Hoàn thiện và chờ duyệt hồ sơ để bắt đầu nhận chuyến.'
                              : online
                              ? 'Sẵn sàng kết nối bạn với chuyến đi tiếp theo. Giữ ứng dụng mở để cập nhật vị trí.'
                              : 'Bật nhận chuyến khi bạn đã sẵn sàng.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: grapMuted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: view.busy || !approved
                              ? null
                              : () => widget.onToggle(!online),
                          icon: Icon(
                            online
                                ? Icons.pause_circle_outline_rounded
                                : Icons.power_settings_new_rounded,
                          ),
                          label: Text(
                            view.busy
                                ? 'Đang cập nhật…'
                                : online
                                ? 'Tạm ngừng nhận chuyến'
                                : 'Bật nhận chuyến',
                          ),
                        ),
                        if (!approved)
                          TextButton(
                            onPressed: widget.onOnboarding,
                            child: const Text('Hoàn thiện hồ sơ'),
                          ),
                        if (view.demo)
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: view.busy ? null : _demoPlaces,
                                child: const Text('Vị trí thử nghiệm'),
                              ),
                              TextButton(
                                onPressed: view.busy || !online
                                    ? null
                                    : widget.onPublish,
                                child: const Text('Gửi vị trí thử'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const Positioned(right: 12, bottom: 2, child: GrapMapAttribution()),
          if (view.offer != null)
            Positioned(
              left: 20,
              bottom: 16,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    'Điểm đón chuyến mới',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
