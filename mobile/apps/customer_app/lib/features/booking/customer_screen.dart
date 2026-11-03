import 'dart:async';

import 'package:grap_customer/core/push/push_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grap_customer/core/core.dart';
import 'package:grap_customer/core/widgets/app_widgets.dart';
import 'package:grap_customer/features/account/presentation/account_screens.dart';
import 'package:grap_customer/features/journey/presentation/journey_screens.dart';
import 'package:grap_customer/features/privacy/presentation/privacy_screens.dart';

import 'customer_controller.dart';
import 'widgets/booking_action_bar.dart';
import 'widgets/booking_place_sheet.dart';
import 'widgets/ride_service_picker.dart';

class CustomerScreen extends ConsumerStatefulWidget {
  final GrapUser user;
  const CustomerScreen({super.key, required this.user});
  @override
  ConsumerState<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends ConsumerState<CustomerScreen>
    with WidgetsBindingObserver {
  int tab = 0;
  CustomerController get controller =>
      ref.read(customerControllerProvider.notifier);
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
    final snapshot = ref.watch(customerControllerProvider);
    final booking = snapshot.asData?.value;

    ref.listen(pushIntentProvider, (previous, next) {
      if (next == null ||
          ref.read(sessionProvider).value?.id != next.message.userId) {
        return;
      }
      if (next.opened && const ['ride', 'offer'].contains(next.message.kind)) {
        setState(() => tab = 0);
      }
      if (snapshot.hasError) {
        ref.invalidate(customerControllerProvider);
      } else {
        unawaited(controller.refresh());
      }
    });
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 66,
        backgroundColor: const Color(0xfff7f9f8),
        title: const GrapBrandLockup(),
        actions: [
          IconButton(
            tooltip: 'Thông báo',
            icon: const Icon(Icons.notifications_none_rounded, color: grapInk),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const NotificationsScreen(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Hỗ trợ',
            icon: const Icon(Icons.headset_mic_outlined, color: grapInk),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const SupportInboxScreen(),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tab == 0 && booking != null && booking.ride == null)
            BookingActionBar(
              quote: booking.quote,
              busy: booking.busy,
              hasRoute: booking.pickup != null && booking.dropoff != null,
              onQuote: controller.quote,
              onBook: controller.book,
            ),
          NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (index) => setState(() => tab = index),
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xffe4f3e9),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded, color: grapGreen),
                label: 'Đặt xe',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                label: 'Hành trình',
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
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GrapNotice(error.toString(), error: true),
                FilledButton(
                  onPressed: () => ref.invalidate(customerControllerProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
        data: (s) => RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: tab == 0 && s.ride == null
                ? EdgeInsets.zero
                : const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              GrapRecoveryBanner(onRecovered: controller.refresh),
              if (s.error != null) GrapNotice(s.error!, error: true),
              if (s.message != null) GrapNotice(s.message!),
              if (tab == 0) ...(s.ride == null ? _booking(s) : _activeRide(s)),
              if (tab == 1)
                GrapHistoryPanel(
                  onRebook: (ride) {
                    controller.rebook(ride);
                    setState(() => tab = 0);
                  },
                ),
              if (tab == 2) ...[
                const Text(
                  'Không gian của bạn',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    color: grapInk,
                  ),
                ),
                const SizedBox(height: 22),
                const GrapAccountPanel(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _choosePlace(CustomerState s, {required bool pickup}) async {
    final place = await showModalBottomSheet<Place>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => BookingPlaceSheet(
        title: pickup ? 'Chọn điểm đón' : 'Bạn muốn đến đâu?',
        selected: pickup ? s.pickup : s.dropoff,
        places: s.places,
      ),
    );
    if (!mounted || place == null) return;
    if (pickup) {
      controller.selectPickup(place);
    } else {
      controller.selectDropoff(place);
    }
  }

  Widget _placeField(CustomerState s, {required bool pickup}) {
    final place = pickup ? s.pickup : s.dropoff;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: GrapIconBadge(
        pickup ? Icons.my_location_rounded : Icons.location_on_rounded,
        size: 36,
      ),
      title: Text(
        pickup ? 'Điểm đón' : 'Điểm đến',
        style: const TextStyle(fontSize: 14, color: grapMuted),
      ),
      subtitle: Text(
        place?.address ?? (pickup ? 'Chọn điểm đón' : 'Bạn muốn đến đâu?'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: grapInk,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: grapMuted),
      onTap: s.busy ? null : () => _choosePlace(s, pickup: pickup),
    );
  }

  Future<void> _chooseSavedDestination() async {
    final place = await Navigator.push<Place>(
      context,
      MaterialPageRoute(builder: (_) => const SavedPlacesScreen(select: true)),
    );
    if (mounted && place != null) controller.selectDropoff(place);
  }

  Widget _quickAction(IconData icon, String label, VoidCallback? onTap) =>
      Expanded(
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              child: Column(
                children: [
                  GrapIconBadge(icon, size: 38),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: grapInk,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  List<Widget> _booking(CustomerState s) => [
    Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (MediaQuery.textScalerOf(context).scale(14) <= 18) ...[
            Text(
              'Chào ${widget.user.name.split(' ').last},',
              style: const TextStyle(fontSize: 14, color: grapMuted),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            'Đi đâu hôm nay?',
            style: TextStyle(
              fontSize: MediaQuery.sizeOf(context).width < 360 ? 25 : 30,
              fontWeight: FontWeight.w800,
              color: grapInk,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Chọn điểm đến, Grap lo chuyến đi.',
            style: TextStyle(fontSize: 14, color: grapMuted),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xffe6ede8)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x060c3825),
                  blurRadius: 16,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _placeField(s, pickup: true),
                  const Divider(height: 1, indent: 68, endIndent: 18),
                  _placeField(s, pickup: false),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Chọn cách bạn di chuyển',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: grapInk,
                    letterSpacing: -.3,
                  ),
                ),
              ),
              const Icon(Icons.tune_rounded, size: 19, color: grapMuted),
            ],
          ),
          const SizedBox(height: 14),
          RideServicePicker(
            selected: s.service,
            enabled: !s.busy,
            onSelected: controller.selectService,
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _quickAction(
                Icons.bookmark_border_rounded,
                'Địa chỉ đã lưu',
                s.busy ? null : _chooseSavedDestination,
              ),
              const SizedBox(width: 10),
              _quickAction(
                Icons.history_rounded,
                'Hành trình',
                () => setState(() => tab = 1),
              ),
              const SizedBox(width: 10),
              _quickAction(
                Icons.shield_outlined,
                'An toàn',
                () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const SafetyContactsScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xffe6ede8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Điểm đón & điểm đến',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(Icons.route_rounded, color: grapGreen, size: 21),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: GrapMap(
                    pickup: s.pickup,
                    dropoff: s.dropoff,
                    height: 200,
                    borderRadius: 16,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.payments_outlined,
                        size: 20,
                        color: grapGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${serviceLabel(s.service)} · Tiền mặt',
                          style: const TextStyle(
                            fontSize: 14,
                            color: grapMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (s.quote != null) ...[
            const SizedBox(height: 12),
            Text(
              '${(s.quote!.distanceMeters / 1000).toStringAsFixed(1)} km · Khoảng ${(s.quote!.durationSeconds / 60).ceil()} phút',
              style: const TextStyle(fontSize: 14, color: grapMuted),
            ),
            const GrapNotice(
              'Kiểm tra hành trình và giá trước khi xác nhận. Phụ phí chỉ tính khi bạn chấp thuận.',
            ),
          ],
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff123e30), Color(0xff1b6547)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 34,
                  color: Color(0xffccebd7),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'An tâm trên mọi chuyến đi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Kiểm tra biển số, xác nhận PIN và lưu liên hệ tin cậy.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Color(0xffd8e9df),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const SafetyContactsScreen(),
                          ),
                        ),
                        child: const Text('Xem tính năng an toàn →'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (s.demo)
            const GrapNotice(
              'Chế độ phát triển: chọn địa điểm mẫu. Tuyến và thời gian không phải kết quả định tuyến thật.',
            ),
        ],
      ),
    ),
  ];
  List<Widget> _activeRide(CustomerState s) {
    final ride = s.ride!;
    return [
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
      Text(
        stateLabel(ride.status),
        style: const TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w700,
          color: grapInk,
        ),
      ),
      const SizedBox(height: 20),
      GrapMap(
        pickup: ride.pickup,
        dropoff: ride.dropoff,
        driver: ride.driver?.location,
      ),
      const SizedBox(height: 18),
      GrapCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RouteSummary(ride),
            const Divider(),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                const Text(
                  'Cước chuyến · Tiền mặt',
                  style: TextStyle(color: grapMuted, fontSize: 14),
                ),
                Text(
                  vnd(ride.fare.payable),
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: grapGreen,
                  ),
                ),
              ],
            ),
            if (ride.pickupPin != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xfff0f8f2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    const Text(
                      'MÃ XÁC NHẬN ĐÓN KHÁCH',
                      style: TextStyle(
                        fontSize: 14,
                        letterSpacing: 1,
                        color: grapMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      ride.pickupPin!,
                      style: const TextStyle(
                        fontSize: 37,
                        letterSpacing: 15,
                        fontWeight: FontWeight.w700,
                        color: grapGreen,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Chỉ cung cấp sau khi đã gặp đúng tài xế.',
                      style: TextStyle(fontSize: 14, color: grapMuted),
                    ),
                  ],
                ),
              ),
            ],
            if (ride.driver != null) ...[
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xffe9f4ed),
                  child: Icon(Icons.person_outline, color: grapGreen),
                ),
                title: Text(
                  ride.driver!.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${ride.driver!.vehicle} · ${ride.driver!.color}\n${ride.driver!.plate}',
                  style: const TextStyle(fontSize: 14, height: 1.7),
                ),
              ),
              if (ride.driver!.locationAt == null ||
                  DateTime.now()
                          .difference(ride.driver!.locationAt!)
                          .inSeconds >
                      30)
                const GrapNotice(
                  'Vị trí tài xế đang gián đoạn hoặc chưa được cập nhật. Chuyến vẫn tiếp tục.',
                ),
            ],
            if (ride.payment != null) ...[
              const Divider(),
              GrapStatus(ride.payment!.status),
              const SizedBox(height: 8),
              Text(
                'Còn phải thanh toán: ${vnd(ride.payment!.remaining)}',
                style: const TextStyle(fontSize: 14, color: grapMuted),
              ),
            ],
            const SizedBox(height: 20),
            if ([
              'SEARCHING',
              'ASSIGNED',
              'DRIVER_ARRIVED',
            ].contains(ride.status))
              OutlinedButton(
                onPressed: s.busy
                    ? null
                    : () async {
                        final reason = await askText(
                          context,
                          'Lý do hủy chuyến',
                        );
                        if (reason != null) await controller.cancel(reason);
                      },
                child: const Text('Hủy chuyến · Miễn phí'),
              ),
            if (ride.active) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: s.busy
                          ? null
                          : () async {
                              await showDialog<void>(
                                context: context,
                                builder: (_) => RideShareSheet(ride: ride),
                              );
                            },
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text(
                        'Chia sẻ',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: s.busy
                          ? null
                          : () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Gửi cảnh báo an toàn?'),
                                  content: const Text(
                                    'Gửi cho đội hỗ trợ nội bộ khi có mạng. Chưa cam kết lực lượng khẩn cấp đã tiếp nhận.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Quay lại'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Gửi cảnh báo'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) await controller.sos();
                            },
                      icon: const Icon(
                        Icons.shield_outlined,
                        size: 18,
                        color: Color(0xffc88b72),
                      ),
                      label: const Text(
                        'SOS',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xffc88b72),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (!ride.active) ...[
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => RideReceiptScreen(rideId: ride.id),
                  ),
                ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Chi tiết cước và đánh giá'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: controller.newBooking,
                child: const Text('Đặt hành trình mới'),
              ),
            ],
          ],
        ),
      ),
    ];
  }
}
