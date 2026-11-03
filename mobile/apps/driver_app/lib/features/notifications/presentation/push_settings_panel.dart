import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grap_driver/core/push/push_providers.dart';
import 'package:grap_driver/core/widgets/app_widgets.dart';

class PushSettingsPanel extends ConsumerWidget {
  const PushSettingsPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(pushCoordinatorProvider);
    final state = ref.watch(pushStatusProvider).value ?? service.status;
    return GrapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Thông báo trên thiết bị',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 10),
          Text(
            !state.available
                ? 'Firebase chưa khả dụng trên nền tảng hoặc cấu hình hiện tại.'
                : state.registered
                ? 'Đã đăng ký nhận thông báo.'
                : state.permission == 'denied'
                ? 'Quyền thông báo đang bị tắt trong cài đặt thiết bị.'
                : 'Bật thông báo để nhận cập nhật chuyến xe và hỗ trợ.',
            style: const TextStyle(fontSize: 14, height: 1.6),
          ),
          if (state.registered && !state.deliveryEnabled)
            const GrapNotice(
              'Thiết bị đã sẵn sàng. Backend chưa bật gửi Firebase; cần cấu hình thông tin xác thực máy chủ.',
            ),
          if (state.error != null) GrapNotice(state.error!, error: true),
          if (state.available)
            Wrap(
              spacing: 8,
              children: [
                if (!state.registered)
                  FilledButton.icon(
                    onPressed: state.busy
                        ? null
                        : () => service.synchronize(requestPermission: true),
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Bật thông báo'),
                  ),
                if (state.permission == 'denied')
                  OutlinedButton(
                    onPressed: () => service.gateway.openSettings(),
                    child: const Text('Mở cài đặt thiết bị'),
                  ),
                if (state.registered)
                  TextButton(
                    onPressed: state.busy ? null : service.disable,
                    child: const Text('Tắt trên thiết bị này'),
                  ),
                if (state.registered && state.deliveryEnabled)
                  OutlinedButton(
                    onPressed: state.busy
                        ? null
                        : () async {
                            try {
                              await service.sendTest();
                              if (context.mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Đã xếp hàng thông báo thử cho tài khoản của bạn.',
                                    ),
                                  ),
                                );
                            } catch (e) {
                              if (context.mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                            }
                          },
                    child: const Text('Gửi thông báo thử'),
                  ),
                IconButton(
                  tooltip: 'Đồng bộ trạng thái thông báo',
                  onPressed: state.busy ? null : () => service.synchronize(),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          if (state.busy) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
