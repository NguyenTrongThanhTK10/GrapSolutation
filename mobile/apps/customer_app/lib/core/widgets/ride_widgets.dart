import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/models.dart';
import '../theme/app_theme.dart';

class RouteSummary extends StatelessWidget {
  final RideSnapshot ride;
  const RouteSummary(this.ride, {super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final pair in [
        (ride.pickup, Icons.my_location, grapGreen),
        (ride.dropoff, Icons.location_on_outlined, const Color(0xffbc9166)),
      ])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(pair.$2, color: pair.$3, size: 20),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  pair.$1.address,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xff61796a),
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class RideHistoryTile extends StatelessWidget {
  final RideSnapshot ride;
  final VoidCallback? onTap;
  const RideHistoryTile(this.ride, {super.key, this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    onTap: onTap,
    leading: CircleAvatar(
      backgroundColor: const Color(0xffedf6ef),
      child: Icon(
        ride.service == 'BIKE' ? Icons.two_wheeler : Icons.directions_car,
        color: grapGreen,
        size: 22,
      ),
    ),
    title: Text(
      ride.dropoff.address,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '${DateFormat('dd/MM HH:mm').format(ride.createdAt.toLocal())} · ${stateLabel(ride.status)}',
        style: const TextStyle(fontSize: 14, color: grapMuted),
      ),
    ),
    trailing: Text(
      vnd(ride.fare.payable),
      style: const TextStyle(
        fontSize: 14,
        color: grapInk,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
