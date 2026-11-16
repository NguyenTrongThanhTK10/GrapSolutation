import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grap_driver/core/core.dart';
import 'package:grap_driver/core/widgets/app_widgets.dart';

import '../driver_controller.dart';
import 'driver_earnings_panel.dart';

class DriverMapHome extends ConsumerStatefulWidget {
  final DriverViewState view;
  final String name;
  final VoidCallback onEarnings;
  final ValueChanged<Place> onChoosePlace;
  final Future<void> Function() onPublish, onRefresh;
  const DriverMapHome({
    super.key,
    required this.view,
    required this.name,
    required this.onEarnings,
    required this.onChoosePlace,
    required this.onPublish,
    required this.onRefresh,
  });
  @override
  ConsumerState<DriverMapHome> createState() => _DriverMapHomeState();
}

class _DriverMapHomeState extends ConsumerState<DriverMapHome> {
  Place? devicePosition;
  DateTime? deviceRecordedAt;
  bool locating = false;
  int cameraRevision = 0;

  Future<void> _locate() async {
    if (locating) return;
    setState(() => locating = true);
    try {
      final position = await ref.read(locationProvider).current();
      if (mounted) {
        setState(() {
          devicePosition = Place(
            id: 'device',
            address: 'Vị trí của bạn',
            latitude: position.latitude,
            longitude: position.longitude,
          );
          deviceRecordedAt = position.recordedAt;
          cameraRevision++;
        });
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
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .6,
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
                trailing: widget.view.developmentPlace?.id == place.id
                    ? const Icon(Icons.check_circle, color: grapGreen)
                    : null,
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

  Widget _status(bool online) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 12)],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: online ? grapBrand : grapMuted,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            online ? 'Đang nhận chuyến' : 'Bạn đang ngoại tuyến',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: grapInk,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _gps(DriverViewState view) => ExpiryBuilder(
    deadline:
        view.position?.recordedAt.add(const Duration(seconds: 30)) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    builder: (seconds) {
      final online = view.availability?.online == true;
      final fresh = seconds > 0 && view.locationError == null;
      final warning = online && !fresh;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: warning ? const Color(0xfffff4df) : const Color(0xffedf6ef),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              warning ? Icons.gps_not_fixed_rounded : Icons.gps_fixed_rounded,
              size: 17,
              color: warning ? grapWarning : grapGreen,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                view.demo
                    ? 'Vị trí thử nghiệm'
                    : fresh
                    ? 'Vị trí đã cập nhật'
                    : online
                    ? 'Cần cập nhật vị trí'
                    : 'GPS khi bật nhận chuyến',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: warning ? grapWarning : grapGreen,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final online = view.availability?.online == true;
    final approved = view.availability?.reviewStatus == 'APPROVED';
    final position = view.position;
    final ownPosition = view.demo
        ? view.developmentPlace
        : position == null ||
              (deviceRecordedAt?.isAfter(position.recordedAt) ?? false)
        ? devicePosition
        : Place(
            id: 'driver-position',
            address: 'Vị trí của bạn',
            latitude: position.latitude,
            longitude: position.longitude,
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final roomy =
            constraints.maxHeight >= 470 &&
            MediaQuery.textScalerOf(context).scale(14) <= 20;
        return ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: GrapMap(
                  cameraRevision: cameraRevision,
                  pickup: view.offer?.pickup,
                  driver: ownPosition,
                  height: constraints.maxHeight,
                  borderRadius: 0,
                  showControls: false,
                  showAttribution: false,
                ),
              ),
              if (constraints.maxHeight >= 120) ...[
                if (roomy)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xfff7f9f8), Color(0x00f7f9f8)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chào ${widget.name}, chúc bạn một ngày thuận lợi',
                            style: const TextStyle(
                              fontSize: 13,
                              color: grapMuted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DriverEarningsHero(
                            earnings: view.earnings,
                            onTap: widget.onEarnings,
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  top: roomy ? 194 : 14,
                  left: 16,
                  right: 74,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _status(online),
                  ),
                ),
                Positioned(
                  top: roomy ? 190 : 10,
                  right: 14,
                  child: Column(
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Vị trí của tôi',
                        onPressed: locating ? null : _locate,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: grapInk,
                          minimumSize: const Size(48, 48),
                        ),
                        icon: locating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location_rounded),
                      ),
                      const SizedBox(height: 8),
                      IconButton.filledTonal(
                        tooltip: 'Làm mới trạng thái',
                        onPressed: view.busy ? null : widget.onRefresh,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: grapInk,
                          minimumSize: const Size(48, 48),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                ),
                if (view.offer == null && constraints.maxHeight >= 280)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 22,
                    child: Material(
                      color: Colors.white,
                      elevation: 4,
                      shadowColor: const Color(0x1a000000),
                      borderRadius: BorderRadius.circular(24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * .42,
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                view.availability == null
                                    ? 'Cần kiểm tra trạng thái'
                                    : !approved
                                    ? 'Sẵn sàng trở thành đối tác'
                                    : online
                                    ? 'Đang chờ chuyến phù hợp'
                                    : 'Sẵn sàng cho chuyến mới?',
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  color: grapInk,
                                  letterSpacing: -.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                !approved
                                    ? 'Hoàn thiện hồ sơ để bắt đầu nhận chuyến.'
                                    : online
                                    ? 'Giữ ứng dụng mở để cập nhật vị trí và nhận lời mời.'
                                    : 'Bật nhận chuyến khi bạn sẵn sàng lên đường.',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: grapMuted,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _gps(view),
                              if (view.locationError != null && online) ...[
                                const SizedBox(height: 8),
                                Text(
                                  view.locationError!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: grapWarning,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: view.busy
                                      ? null
                                      : widget.onPublish,
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Cập nhật vị trí'),
                                ),
                              ],
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
              ],
              const Positioned(
                right: 8,
                bottom: 2,
                child: GrapMapAttribution(),
              ),
            ],
          ),
        );
      },
    );
  }
}
