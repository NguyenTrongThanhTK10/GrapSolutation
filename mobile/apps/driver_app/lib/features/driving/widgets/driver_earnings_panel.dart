import 'package:flutter/material.dart';
import 'package:grap_driver/core/core.dart';
import 'package:grap_driver/core/widgets/app_widgets.dart';

class DriverEarningsHero extends StatelessWidget {
  final Earnings? earnings;
  final VoidCallback? onTap;
  final bool compact;
  const DriverEarningsHero({
    super.key,
    this.earnings,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xff123f31), Color(0xff087f50)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x240b5637),
          blurRadius: 20,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 18 : 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thu nhập từ chuyến',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .8),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      earnings == null
                          ? 'Xem thu nhập'
                          : vnd(earnings!.entitlement),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 25 : 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.7,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      earnings == null
                          ? 'Mở bảng thu nhập của bạn'
                          : 'Lũy kế · ${earnings!.completedRides} chuyến hoàn tất',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: .8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  onTap == null
                      ? Icons.account_balance_wallet_outlined
                      : Icons.arrow_outward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class DriverWalletGrid extends StatelessWidget {
  final Earnings earnings;
  const DriverWalletGrid({super.key, required this.earnings});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final twoColumns =
          constraints.maxWidth >= 340 &&
          MediaQuery.textScalerOf(context).scale(14) <= 20;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final (label, amount, icon, color) in [
            (
              'Khả dụng',
              earnings.available,
              Icons.account_balance_wallet_outlined,
              grapGreen,
            ),
            (
              'Chờ đối soát',
              earnings.pending,
              Icons.schedule_rounded,
              grapMuted,
            ),
            ('Đang giữ', earnings.held, Icons.lock_outline_rounded, grapMuted),
            (
              'Công nợ cần nộp',
              earnings.debt,
              Icons.receipt_long_outlined,
              grapWarning,
            ),
          ])
            SizedBox(
              width: twoColumns
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth,
              child: GrapCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: color, size: 22),
                    const SizedBox(height: 12),
                    Text(
                      label,
                      style: const TextStyle(color: grapMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      vnd(amount),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
