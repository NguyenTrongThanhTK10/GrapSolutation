import 'package:flutter/material.dart';
import 'package:grap_driver/core/domain/models.dart';
import 'package:grap_driver/core/widgets/app_widgets.dart';

class DriverOfferBar extends StatelessWidget {
  final DriverOffer offer;
  final bool busy;
  final VoidCallback onAccept, onReject;

  const DriverOfferBar({
    super.key,
    required this.offer,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) => ExpiryBuilder(
    deadline: offer.expiresAt,
    builder: (seconds) => MediaQuery.sizeOf(context).height < 500
        ? _compact(seconds)
        : GrapActionSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Bạn nhận ${vnd(offer.entitlement)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: grapInk,
                      ),
                    ),
                    Text(
                      seconds > 0 ? 'Còn $seconds giây' : 'Đã hết hạn',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: seconds <= 5 ? grapDanger : grapGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Đón tại ${offer.pickup.address}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: grapMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  '${serviceLabel(offer.service)} · Thu khách ${vnd(offer.payable)}',
                  style: const TextStyle(fontSize: 14, color: grapMuted),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: busy ? null : onReject,
                        child: const Text('Bỏ qua'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: FilledButton(
                        onPressed: busy || seconds == 0 ? null : onAccept,
                        child: Text(busy ? 'Đang nhận…' : 'Nhận chuyến'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
  );
  Widget _compact(int seconds) => GrapActionSurface(
    child: Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${vnd(offer.entitlement)} · Bạn nhận',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: grapInk,
                ),
              ),
              Text(
                seconds > 0 ? 'Còn $seconds giây' : 'Đã hết hạn',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: seconds <= 5 ? grapDanger : grapGreen,
                ),
              ),
              Text(
                'Đón tại ${offer.pickup.address}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: grapMuted),
              ),
              Text(
                '${vnd(offer.payable)} · Thu khách',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: grapMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 180,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: busy || seconds == 0 ? null : onAccept,
                child: Text(busy ? 'Đang nhận…' : 'Nhận chuyến'),
              ),
              TextButton(
                onPressed: busy ? null : onReject,
                child: const Text('Bỏ qua'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
