import 'package:flutter/material.dart';
import 'package:grap_driver/core/core.dart';
import 'package:grap_driver/core/widgets/app_widgets.dart';

class DriverTripHeading extends StatelessWidget {
  final RideSnapshot ride;
  const DriverTripHeading({super.key, required this.ride});
  @override
  Widget build(BuildContext context) {
    final stage = ride.status == 'COMPLETED'
        ? 2
        : ride.status == 'IN_PROGRESS'
        ? 1
        : 0;
    final title = switch (ride.status) {
      'ASSIGNED' => 'Đến đón khách',
      'DRIVER_ARRIVED' => 'Chờ khách lên xe',
      'IN_PROGRESS' => 'Đưa khách đến nơi',
      'COMPLETED' => 'Chuyến đi đã hoàn tất',
      _ => stateLabel(ride.status),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${ride.code} · ${serviceLabel(ride.service)}',
          style: const TextStyle(fontSize: 13, color: grapMuted),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            letterSpacing: -.7,
            color: grapInk,
          ),
        ),
        if (ride.active || ride.status == 'COMPLETED') ...[
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (index, label, icon) in [
                (0, 'Đón khách', Icons.person_pin_circle_outlined),
                (1, 'Di chuyển', Icons.navigation_outlined),
                (2, 'Hoàn tất', Icons.flag_outlined),
              ]) ...[
                if (index > 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 17),
                    child: SizedBox(width: 18, child: Divider(height: 1)),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: index <= stage
                              ? grapGreen
                              : const Color(0xffeaf0ec),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          index < stage ? Icons.check_rounded : icon,
                          size: 20,
                          color: index <= stage ? Colors.white : grapMuted,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: index == stage ? grapGreen : grapMuted,
                          fontWeight: index == stage
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
