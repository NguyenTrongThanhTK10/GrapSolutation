import 'package:flutter/material.dart';
import 'package:grap_driver/core/core.dart';
import 'package:grap_driver/core/widgets/app_widgets.dart';

import '../driver_controller.dart';

class DriverAvailabilityBar extends StatelessWidget {
  final DriverViewState view;
  final VoidCallback onToggle, onOnboarding, onRefresh;
  const DriverAvailabilityBar({
    super.key,
    required this.view,
    required this.onToggle,
    required this.onOnboarding,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final online = view.availability?.online == true;
    final approved = view.availability?.reviewStatus == 'APPROVED';
    final unknown = view.availability == null;
    return GrapActionSurface(
      child: FilledButton.icon(
        key: const ValueKey('driver-availability-action'),
        onPressed: view.busy
            ? null
            : unknown
            ? onRefresh
            : approved
            ? onToggle
            : onOnboarding,
        style: FilledButton.styleFrom(
          backgroundColor: online ? grapInk : grapGreen,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
        icon: Icon(
          unknown
              ? Icons.refresh_rounded
              : !approved
              ? Icons.badge_outlined
              : online
              ? Icons.pause_rounded
              : Icons.power_settings_new_rounded,
        ),
        label: Text(
          view.busy
              ? 'Đang cập nhật…'
              : unknown
              ? 'Tải lại trạng thái'
              : !approved
              ? 'Hoàn thiện hồ sơ'
              : online
              ? 'Tạm ngừng nhận chuyến'
              : 'Bật nhận chuyến',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class DriverTripActionBar extends StatelessWidget {
  final RideSnapshot ride;
  final bool busy;
  final VoidCallback onNavigate, onAction;
  const DriverTripActionBar({
    super.key,
    required this.ride,
    required this.busy,
    required this.onNavigate,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 500;
    final (label, icon) = switch (ride.status) {
      'ASSIGNED' => (
        compact ? 'Đã đến' : 'Tôi đã đến điểm đón',
        Icons.place_outlined,
      ),
      'DRIVER_ARRIVED' => (
        compact ? 'Bắt đầu' : 'Xác nhận PIN & bắt đầu',
        Icons.password_rounded,
      ),
      _ => (
        compact ? 'Hoàn tất' : 'Hoàn tất chuyến đi',
        Icons.check_circle_outline_rounded,
      ),
    };
    return GrapActionSurface(
      child: Row(
        children: [
          IconButton.outlined(
            tooltip: 'Mở chỉ đường',
            onPressed: onNavigate,
            style: IconButton.styleFrom(
              minimumSize: const Size(56, 56),
              foregroundColor: grapGreen,
              side: const BorderSide(color: Color(0xffd6e5dc)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.navigation_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              key: const ValueKey('driver-trip-action'),
              onPressed: busy ? null : onAction,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
              icon: Icon(icon),
              label: Text(
                busy ? 'Đang xử lý…' : label,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
