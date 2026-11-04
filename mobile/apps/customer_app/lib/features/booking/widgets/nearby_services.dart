import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grap_customer/core/core.dart';
import 'package:grap_customer/core/widgets/app_widgets.dart';

class NearbyServicesPanel extends ConsumerWidget {
  final Place pickup;
  const NearbyServicesPanel({super.key, required this.pickup});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = nearbyServicesProvider(pickup);
    final state = ref.watch(provider);
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
        state.when(
          skipLoadingOnRefresh: false,
          loading: () => const LinearProgressIndicator(
            semanticsLabel: 'Đang kiểm tra xe gần điểm đón',
          ),
          error: (_, _) => const Text(
            'Chưa kiểm tra được xe gần đây. Bạn vẫn có thể xem giá và gửi yêu cầu đặt xe.',
            style: TextStyle(fontSize: 13, color: grapMuted),
          ),
          data: (data) => ExpiryBuilder(
            deadline: data.freshUntil,
            builder: (seconds) {
              if (seconds == 0) {
                return const Text(
                  'Thông tin xe đã cũ. Nhấn cập nhật để kiểm tra lại.',
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
                    '${data.counts.values.fold<int>(0, (sum, value) => sum + value)} xe vừa kiểm tra trong ${(data.radiusMeters / 1000).toStringAsFixed(0)} km',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: grapGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Xem số xe theo loại ở bên dưới. Số lượng có thể thay đổi; tài xế xác nhận sau khi bạn đặt.',
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
