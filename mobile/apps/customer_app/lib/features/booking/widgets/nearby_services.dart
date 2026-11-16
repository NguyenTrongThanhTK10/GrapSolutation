import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grap_customer/core/core.dart';
import 'package:grap_customer/core/widgets/app_widgets.dart';

class NearbyServicesPanel extends ConsumerWidget {
  final Place pickup;
  final String? service;
  const NearbyServicesPanel({super.key, required this.pickup, this.service});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = nearbyServicesProvider(pickup);
    final state = ref.watch(provider);
    final data = state.hasError ? null : state.asData?.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Xe gần điểm đón',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            IconButton(
              tooltip: 'Cập nhật xe gần đây',
              onPressed: state.isLoading
                  ? null
                  : () => ref.invalidate(provider),
              icon: const Icon(Icons.refresh, size: 20),
            ),
          ],
        ),
        if (service != null) ...[
          ExpiryBuilder(
            deadline:
                data?.freshUntil ?? DateTime.fromMillisecondsSinceEpoch(0),
            builder: (seconds) => GrapMap(
              pickup: pickup,
              height: 260,
              nearbyDrivers: seconds == 0 || data?.inServiceZone != true
                  ? const []
                  : data!.drivers
                        .where(
                          (driver) =>
                              driver.service == service &&
                              driver.freshUntil.isAfter(DateTime.now()),
                        )
                        .toList(),
            ),
          ),
          const SizedBox(height: 10),
        ],
        state.when(
          skipLoadingOnRefresh: false,
          loading: () => const LinearProgressIndicator(
            semanticsLabel: 'Đang kiểm tra xe gần điểm đón',
          ),
          error: (_, _) => const Text(
            'Chưa kiểm tra được xe gần đây. Đang kết nối lại. Bạn vẫn có thể xem giá và đặt xe.',
            style: TextStyle(fontSize: 13, color: grapMuted),
          ),
          data: (data) => ExpiryBuilder(
            deadline: data.freshUntil,
            builder: (seconds) {
              if (seconds == 0) {
                return const Text(
                  'Thông tin xe đã cũ. Đang cập nhật lại vị trí tài xế.',
                  style: TextStyle(fontSize: 13, color: grapMuted),
                );
              }
              if (!data.inServiceZone) {
                return const Text(
                  'Điểm đón hiện nằm ngoài vùng phục vụ. Hãy chọn điểm khác.',
                  style: TextStyle(color: grapWarning),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${service == null ? data.counts.values.fold<int>(0, (sum, value) => sum + value) : data.counts[service] ?? 0} xe${service == null ? '' : ' ${serviceLabel(service!)}'} trong ${(data.radiusMeters / 1000).toStringAsFixed(0)} km',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: grapGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tự cập nhật vị trí xe gần đúng. Chọn loại xe bên dưới để xem trên bản đồ; tài xế xác nhận sau khi bạn đặt.',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: grapMuted,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
