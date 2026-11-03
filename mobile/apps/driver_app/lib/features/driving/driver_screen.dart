import 'dart:async';

import 'package:grap_driver/core/push/push_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grap_driver/core/core.dart';
import 'package:grap_driver/core/widgets/app_widgets.dart';
import 'package:grap_driver/features/account/presentation/account_screens.dart';
import 'package:grap_driver/features/journey/presentation/journey_screens.dart';
import 'package:grap_driver/features/privacy/presentation/privacy_screens.dart';
import 'package:url_launcher/url_launcher.dart';

import 'driver_controller.dart';
import 'widgets/driver_offer_bar.dart';
import 'widgets/driver_map_home.dart';
import '../onboarding/onboarding_screen.dart';

class DriverScreen extends ConsumerStatefulWidget {
  final GrapUser user;
  const DriverScreen({super.key, required this.user});
  @override
  ConsumerState<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends ConsumerState<DriverScreen>
    with WidgetsBindingObserver {
  int tab = 0;
  DriverController get controller =>
      ref.read(driverControllerProvider.notifier);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    controller.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(driverControllerProvider);
    final current = snapshot.asData?.value;
    final offer = current?.ride?.active == true ? null : current?.offer;
    ref.listen(pushIntentProvider, (previous, next) {
      if (next == null ||
          ref.read(sessionProvider).value?.id != next.message.userId) {
        return;
      }
      if (next.opened && const ['ride', 'offer'].contains(next.message.kind)) {
        setState(() => tab = 0);
      }
      if (snapshot.hasError) {
        ref.invalidate(driverControllerProvider);
      } else {
        unawaited(controller.refresh());
      }
    });
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 66,
        title: const GrapBrandLockup(driver: true),
        actions: [
          IconButton(
            tooltip: 'Liên hệ tin cậy',
            icon: const Icon(
              Icons.health_and_safety_outlined,
              color: grapGreen,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const SafetyContactsScreen(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Hỗ trợ',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const SupportInboxScreen(),
                ),
              );
            },
            icon: const Icon(Icons.headset_mic_outlined, color: grapGreen),
          ),
          const SizedBox(width: 10),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (offer != null && current != null)
            DriverOfferBar(
              offer: offer,
              busy: current.busy,
              onAccept: controller.accept,
              onReject: controller.reject,
            ),
          NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xffe4f3e9),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                label: 'Nhận chuyến',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                label: 'Thu nhập',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                label: 'Tài khoản',
              ),
            ],
          ),
        ],
      ),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GrapNotice(e.toString(), error: true),
                FilledButton(
                  onPressed: () => ref.invalidate(driverControllerProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
        data: (s) => tab == 0 && s.ride == null
            ? Column(
                children: [
                  GrapRecoveryBanner(onRecovered: controller.refresh),
                  if (s.error != null) GrapNotice(s.error!, error: true),
                  if (s.message != null) GrapNotice(s.message!),
                  Expanded(
                    child: DriverMapHome(
                      view: s,
                      onToggle: controller.toggle,
                      onEarnings: () => setState(() => tab = 1),
                      onOnboarding: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const OnboardingScreen(),
                          ),
                        );
                        if (mounted) await controller.refresh();
                      },
                      onChoosePlace: controller.choosePlace,
                      onPublish: controller.publishLocation,
                      onRefresh: controller.refresh,
                    ),
                  ),
                ],
              )
            : RefreshIndicator(
                onRefresh: controller.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                  children: [
                    GrapRecoveryBanner(onRecovered: controller.refresh),
                    if (s.error != null) GrapNotice(s.error!, error: true),
                    if (s.message != null) GrapNotice(s.message!),
                    if (tab == 0) ..._home(s),
                    if (tab == 1) ..._earnings(s),
                    if (tab == 2) ...[
                      const Text(
                        'Đối tác tài xế',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w700,
                          color: grapInk,
                        ),
                      ),
                      const SizedBox(height: 22),
                      GrapAccountPanel(
                        extra: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.badge_outlined,
                            color: grapGreen,
                          ),
                          title: const Text(
                            'Hồ sơ, xe & giấy tờ',
                            style: TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            s.availability?.reviewStatus == 'APPROVED'
                                ? 'Hồ sơ đã được duyệt'
                                : 'Hoàn thiện hồ sơ để bật nhận chuyến',
                            style: const TextStyle(fontSize: 14),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const OnboardingScreen(),
                              ),
                            );
                            if (mounted) await controller.refresh();
                          },
                        ),
                      ),
                      const GrapNotice(
                        'Vị trí hiện được gửi khi ứng dụng đang mở. Nếu mất GPS, hệ thống ngừng xét chuyến mới nhưng vẫn giữ chuyến đang thực hiện.',
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  List<Widget> _home(DriverViewState s) {
    final ride = s.ride, offer = s.offer;
    return [
      Text(
        'Chào ${widget.user.name.split(' ').last},',
        style: const TextStyle(fontSize: 14, color: grapMuted),
      ),
      const SizedBox(height: 7),
      Text(
        offer != null && ride?.active != true
            ? 'Có chuyến mới'
            : 'Sẵn sàng nhận chuyến',
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: grapInk,
          height: 1.35,
          letterSpacing: -.7,
        ),
      ),
      const SizedBox(height: 22),
      GrapCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.availability?.online == true
                        ? 'Bạn đang trực tuyến'
                        : 'Bạn đang ngoại tuyến',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: grapInk,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    s.availability?.offlineAfterRide == true
                        ? 'Sẽ nghỉ sau chuyến hiện tại'
                        : 'Bật khi bạn sẵn sàng phục vụ',
                    style: const TextStyle(fontSize: 14, color: grapMuted),
                  ),
                ],
              ),
            ),
            Switch(
              value: s.availability?.online ?? false,
              onChanged: s.busy || s.availability?.reviewStatus != 'APPROVED'
                  ? null
                  : controller.toggle,
            ),
          ],
        ),
      ),
      if (s.availability?.reviewStatus != 'APPROVED')
        const GrapNotice(
          'Hồ sơ chưa được duyệt hoặc cần bổ sung. Bạn chưa thể bật nhận chuyến.',
        ),
      const SizedBox(height: 16),
      GrapMap(
        pickup: offer != null && ride?.active != true
            ? offer.pickup
            : ride?.pickup ?? s.developmentPlace,
        dropoff: offer != null && ride?.active != true ? null : ride?.dropoff,
        height: 260,
      ),
      const SizedBox(height: 16),
      if (s.demo)
        GrapCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'VỊ TRÍ THỬ NGHIỆM · CHỈ LOCAL',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: grapMuted,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: s.developmentPlace?.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Chọn vị trí gửi lên server',
                ),
                items: s.places
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          p.address,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (id) => controller.choosePlace(
                  s.places.firstWhere((p) => p.id == id),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: s.busy || s.availability?.online != true
                    ? null
                    : controller.publishLocation,
                icon: const Icon(Icons.my_location, size: 17),
                label: const Text(
                  'Cập nhật vị trí & heartbeat',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      if (ride != null) ...[
        const SizedBox(height: 16),
        GrapCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    ride.code,
                    style: const TextStyle(fontSize: 14, color: grapMuted),
                  ),
                  GrapStatus(ride.status),
                ],
              ),
              const SizedBox(height: 16),
              RouteSummary(ride),
              const Divider(),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  const Text(
                    'Thu tiền mặt',
                    style: TextStyle(fontSize: 14, color: grapMuted),
                  ),
                  Text(
                    vnd(ride.fare.payable),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: grapGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (ride.active)
                OutlinedButton.icon(
                  onPressed: () async {
                    final point = ride.status == 'IN_PROGRESS'
                        ? ride.dropoff
                        : ride.pickup;
                    final uri = Uri.https('www.google.com', '/maps/dir/', {
                      'api': '1',
                      'destination': '${point.latitude},${point.longitude}',
                    });
                    final opened = await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                    if (!opened && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Không mở được ứng dụng bản đồ. Bạn vẫn xem được điểm đón/đến tại đây.',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.navigation_outlined, size: 18),
                  label: const Text('Mở chỉ đường'),
                ),
              const SizedBox(height: 10),
              if (ride.status == 'ASSIGNED')
                FilledButton(
                  onPressed: s.busy ? null : controller.arrive,
                  child: const Text('Tôi đã đến điểm đón'),
                ),
              if (ride.status == 'DRIVER_ARRIVED')
                FilledButton(
                  onPressed: s.busy
                      ? null
                      : () async {
                          final pin = await askText(
                            context,
                            'Nhập PIN từ khách',
                            hint: '4 chữ số trên app khách hàng',
                            numeric: true,
                          );
                          if (pin != null) await controller.start(pin);
                        },
                  child: const Text('Xác nhận PIN & bắt đầu'),
                ),
              if (ride.status == 'IN_PROGRESS')
                FilledButton(
                  onPressed: s.busy ? null : controller.complete,
                  child: const Text('Hoàn tất chuyến đi'),
                ),
              if (['ASSIGNED', 'DRIVER_ARRIVED'].contains(ride.status))
                TextButton(
                  onPressed: s.busy
                      ? null
                      : () async {
                          final reason = await askText(
                            context,
                            'Lý do rời chuyến',
                          );
                          if (reason != null) await controller.release(reason);
                        },
                  child: const Text('Yêu cầu điều phối lại'),
                ),
              if (ride.status == 'DRIVER_ARRIVED') ...[
                if (ride.arrivedAt != null)
                  ExpiryBuilder(
                    deadline: ride.arrivedAt!.add(const Duration(minutes: 5)),
                    builder: (seconds) => GrapNotice(
                      seconds > 0
                          ? 'Cần chờ thêm $seconds giây trước khi báo khách không xuất hiện.'
                          : 'Đã đủ thời gian chờ. Cần ghi nhận đã thử liên hệ khách trước khi báo no-show.',
                    ),
                  ),
                TextButton(
                  onPressed: s.busy
                      ? null
                      : () async {
                          final note = await askText(
                            context,
                            'Ghi nhận đã thử liên hệ',
                            hint: 'Mô tả lần liên hệ qua kênh được cấp. Không ghi số điện thoại vào đây.',
                          );
                          if (note != null) {
                            await controller.recordContact(note);
                          }
                        },
                  child: const Text('Đã thử liên hệ khách'),
                ),
                TextButton(
                  onPressed: s.busy
                      ? null
                      : () async {
                          final reason = await askText(
                            context,
                            'Khách không xuất hiện',
                            hint: 'Lý do và thông tin liên hệ đã thử; cần đủ thời gian chờ.',
                          );
                          if (reason != null) await controller.noShow(reason);
                        },
                  child: const Text('Báo khách không xuất hiện'),
                ),
              ],
              if (ride.status == 'IN_PROGRESS')
                TextButton(
                  onPressed: s.busy
                      ? null
                      : () async {
                          final reason = await askText(
                            context,
                            'Kết thúc sớm hành trình',
                            hint: 'Nhập lý do. Giá chốt được giữ nguyên; mọi điều chỉnh cần hỗ trợ riêng.',
                          );
                          if (reason != null) await controller.endEarly(reason);
                        },
                  child: const Text('Yêu cầu kết thúc sớm'),
                ),
              if (ride.status == 'IN_PROGRESS')
                TextButton.icon(
                  onPressed: s.busy
                      ? null
                      : () async {
                          final confirm = await askText(
                            context,
                            'Gửi SOS nội bộ',
                            hint: 'Nhập lý do. Chỉ gửi khi có mạng; chưa có xác nhận nhân sự tiếp nhận.',
                          );
                          if (confirm != null) await controller.sos();
                        },
                  icon: const Icon(
                    Icons.shield_outlined,
                    color: Color(0xffbc866d),
                  ),
                  label: const Text(
                    'Hỗ trợ an toàn',
                    style: TextStyle(color: Color(0xffbc866d)),
                  ),
                ),
              if (ride.status == 'COMPLETED' && ride.payment != null) ...[
                GrapStatus(ride.payment!.status),
                const SizedBox(height: 12),
                if (ride.payment!.remaining > 0)
                  FilledButton(
                    onPressed:
                        s.busy ||
                            s.paymentNeedsRefresh ||
                            (ref
                                    .watch(pendingOperationsProvider)
                                    .value
                                    ?.any(
                                      (p) =>
                                          p.path ==
                                          '/payments/${ride.payment!.id}/cash-collections',
                                    ) ??
                                false)
                        ? null
                        : () async {
                            final input = await askText(
                              context,
                              'Thực tế đã thu (VND)',
                              hint: 'Tối đa ${ride.payment!.remaining} đồng',
                              numeric: true,
                            );
                            final amount = int.tryParse(input ?? '');
                            if (amount != null) {
                              await controller.cash(
                                amount,
                                amount == ride.payment!.remaining
                                    ? 'FULL_AMOUNT_RECEIVED'
                                    : 'PARTIAL_OR_UNPAID',
                              );
                            }
                          },
                    child: Text(
                      'Ghi nhận thực thu · ${vnd(ride.payment!.remaining)}',
                    ),
                  ),
                if (s.paymentNeedsRefresh)
                  OutlinedButton.icon(
                    onPressed: s.busy ? null : () => controller.refresh(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Kiểm tra lại thanh toán'),
                  ),
                const SizedBox(height: 10),
              ],
              if (!ride.active)
                TextButton(
                  onPressed: controller.dismissRide,
                  child: const Text('Quay lại nhận chuyến'),
                ),
            ],
          ),
        ),
      ],
      if (ride == null && offer == null)
        GrapNotice(
          s.availability?.online == true
              ? 'Đang chờ chuyến phù hợp. Hãy giữ vị trí và kết nối mới.'
              : 'Bật nhận chuyến khi bạn đã sẵn sàng.',
        ),
    ];
  }

  List<Widget> _earnings(DriverViewState s) {
    final e = s.earnings;
    return [
      const Text(
        'Thu nhập minh bạch.',
        style: TextStyle(
          fontSize: 29,
          fontWeight: FontWeight.w700,
          color: grapInk,
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        'Tách riêng quyền lợi, tiền mặt đã thu và công nợ.',
        style: TextStyle(fontSize: 14, color: grapMuted),
      ),
      const SizedBox(height: 22),
      if (e != null)
        GrapCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'QUYỀN LỢI TỪ CHUYẾN HOÀN TẤT',
                style: TextStyle(
                  fontSize: 14,
                  letterSpacing: 1,
                  color: grapMuted,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                vnd(e.entitlement),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: grapGreen,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                '${e.completedRides} chuyến hoàn tất',
                style: const TextStyle(fontSize: 14, color: grapMuted),
              ),
              const Divider(),
              for (final row in [
                ('Khả dụng', e.available),
                ('Chờ đối soát', e.pending),
                ('Đang giữ', e.held),
                ('Công nợ cần nộp', e.debt),
                ('Hoa hồng nền tảng', e.commission),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text(
                        row.$1,
                        style: const TextStyle(fontSize: 14, color: grapMuted),
                      ),
                      Text(
                        vnd(row.$2),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: grapInk,
                        ),
                      ),
                    ],
                  ),
                ),
              const GrapNotice(
                'Tiền mặt đã cầm không được cộng thêm lần nữa vào số có thể rút. Rút tiền tự phục vụ thuộc giai đoạn P1.',
              ),
            ],
          ),
        ),
      const SizedBox(height: 22),
      const Text(
        'Lịch sử chuyến',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: grapInk,
        ),
      ),
      const SizedBox(height: 15),
      const GrapHistoryPanel(),
    ];
  }
}
