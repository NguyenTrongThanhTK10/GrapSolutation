import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/models.dart';
import '../../../core/domain/ride_route.dart';
import '../../../core/providers/ride_route_providers.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../booking/customer_controller.dart';

class RideJourneyMap extends ConsumerWidget {
  final RideSnapshot ride;
  final bool fullScreen;
  const RideJourneyMap({
    super.key,
    required this.ride,
    this.fullScreen = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (
      id: ride.id,
      version: ride.version,
      locationAt: ride.driver?.locationAt,
    );
    final result = ref.watch(rideRouteProvider(key));
    final route = result.asData?.value ?? const RideRoute();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Bản đồ hành trình',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            if (!fullScreen)
              IconButton(
                tooltip: 'Mở bản đồ toàn màn hình',
                icon: const Icon(Icons.fullscreen_rounded),
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Consumer(
                      builder: (context, ref, child) {
                        final liveRide = ride.active
                            ? ref
                                  .watch(customerControllerProvider)
                                  .asData
                                  ?.value
                                  .ride
                            : null;
                        final displayedRide = liveRide?.id == ride.id
                            ? liveRide!
                            : ride;
                        return Scaffold(
                          appBar: AppBar(
                            title: Text('Hành trình ${ride.code}'),
                          ),
                          body: SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: RideJourneyMap(
                                ride: displayedRide,
                                fullScreen: true,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (fullScreen)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  _map(route, constraints.maxHeight),
            ),
          )
        else
          _map(route, 300),
        const SizedBox(height: 12),
        if (result.isLoading)
          const Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Đang tải tuyến đường…'),
            ],
          )
        else if (result.hasError)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Chưa tải được tuyến đường.'),
              TextButton(
                onPressed: () => ref.invalidate(rideRouteProvider(key)),
                child: const Text('Thử lại tuyến đường'),
              ),
            ],
          )
        else ...[
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (route.planned.length > 1)
                const _Legend(grapGreen, 'Tuyến dự kiến'),
              if (route.recorded.length > 1)
                const _Legend(Color(0xff2563eb), 'GPS đã ghi nhận'),
              if (route.distanceMeters > 0)
                Text(
                  'Dự kiến: ${(route.distanceMeters / 1000).toStringAsFixed(1)} km · '
                  '${(route.durationSeconds / 60).ceil()} phút',
                ),
            ],
          ),
          if (route.planned.length < 2 && route.recorded.length < 2)
            const Text(
              'Chưa có dữ liệu tuyến đường chi tiết. Đường nét đứt chỉ nối điểm đón và điểm đến.',
              style: TextStyle(fontSize: 13, color: grapMuted),
            ),
          if (route.recorded.length < 2 && !ride.active)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Chưa có đủ dữ liệu GPS để hiển thị đường đã di chuyển.',
                style: TextStyle(fontSize: 13, color: grapMuted),
              ),
            ),
        ],
      ],
    );
  }

  Widget _map(RideRoute route, double height) => GrapMap(
    pickup: ride.pickup,
    dropoff: ride.dropoff,
    driver: ride.active ? ride.driver?.location : null,
    routePoints: route.planned,
    recordedPoints: route.recorded,
    height: height,
  );
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 18, height: 4, color: color),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 13)),
    ],
  );
}
