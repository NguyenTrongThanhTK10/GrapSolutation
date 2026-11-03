import 'package:flutter/material.dart';
import 'package:grap_customer/core/domain/models.dart';
import 'package:grap_customer/core/widgets/app_widgets.dart';

class BookingActionBar extends StatelessWidget {
  final QuoteSnapshot? quote;
  final bool busy, hasRoute;
  final VoidCallback onQuote, onBook;

  const BookingActionBar({
    super.key,
    this.quote,
    required this.busy,
    required this.hasRoute,
    required this.onQuote,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final currentQuote = quote;
    if (currentQuote == null) {
      return _layout(
        context,
        summary: Text(
          hasRoute
              ? 'Giá hiển thị trước khi bạn xác nhận'
              : 'Chọn điểm đón và điểm đến để xem giá',
          style: const TextStyle(color: grapMuted, fontSize: 14),
        ),
        action: FilledButton(
          onPressed: busy || !hasRoute ? null : onQuote,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(busy ? 'Đang lấy giá…' : 'Xem giá chuyến đi'),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ),
        ),
      );
    }

    return ExpiryBuilder(
      deadline: currentQuote.expiresAt,
      builder: (seconds) => _layout(
        context,
        summary: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 4,
              children: [
                Text(
                  vnd(currentQuote.fare.payable),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: grapInk,
                  ),
                ),
                if (MediaQuery.sizeOf(context).height >= 500)
                  const Text(
                    'Thanh toán tiền mặt',
                    style: TextStyle(color: grapMuted, fontSize: 14),
                  ),
              ],
            ),
            Text(
              seconds > 0
                  ? 'Giữ giá trong $seconds giây'
                  : 'Giá đã hết hạn. Vui lòng xem giá mới.',
              style: TextStyle(
                color: seconds > 0 ? grapMuted : grapWarning,
                fontSize: 14,
              ),
            ),
          ],
        ),
        action: FilledButton(
          onPressed: busy
              ? null
              : seconds == 0
              ? onQuote
              : onBook,
          child: Text(
            busy
                ? 'Đang xác nhận…'
                : seconds == 0
                ? 'Lấy báo giá mới'
                : 'Xác nhận đặt xe',
          ),
        ),
      ),
    );
  }

  Widget _layout(
    BuildContext context, {
    required Widget summary,
    required Widget action,
  }) => GrapActionSurface(
    child: LayoutBuilder(
      builder: (context, constraints) => MediaQuery.sizeOf(context).height < 500
          ? Row(
              children: [
                Expanded(child: summary),
                const SizedBox(width: 16),
                SizedBox(width: constraints.maxWidth * .42, child: action),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [summary, const SizedBox(height: 10), action],
            ),
    ),
  );
}
