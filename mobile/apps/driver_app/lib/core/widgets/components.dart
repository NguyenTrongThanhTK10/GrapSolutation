import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GrapCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const GrapCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: padding, child: child),
  );
}

class GrapNotice extends StatelessWidget {
  final String message;
  final bool error;
  const GrapNotice(this.message, {super.key, this.error = false});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    margin: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: error ? const Color(0xfffff1eb) : const Color(0xffeef7f0),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          error ? Icons.info_outline : Icons.shield_outlined,
          color: error ? grapDanger : grapGreen,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: error ? grapDanger : grapMuted,
            ),
          ),
        ),
      ],
    ),
  );
}

class GrapStatus extends StatelessWidget {
  final String status;
  const GrapStatus(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final (color, background, icon) = switch (status) {
      'CANCELED' => (
        grapDanger,
        const Color(0xffffefed),
        Icons.cancel_outlined,
      ),
      'NO_DRIVER' ||
      'EXPIRED' ||
      'PENDING' => (grapWarning, const Color(0xfffff3df), Icons.schedule),
      'COMPLETED' || 'SUCCEEDED' => (
        grapGreen,
        const Color(0xffedf7ef),
        Icons.check_circle_outline,
      ),
      _ => (grapGreen, const Color(0xffedf7ef), Icons.route_outlined),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              stateLabel(status),
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A fresh version must be reviewed before another edit is submitted.
class GrapConflictNotice extends StatelessWidget {
  final VoidCallback onReload;
  const GrapConflictNotice({super.key, required this.onReload});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const GrapNotice(
        'Thông tin đã được cập nhật ở nơi khác. Tải bản mới và kiểm tra trước khi lưu.',
      ),
      OutlinedButton.icon(
        onPressed: onReload,
        icon: const Icon(Icons.refresh),
        label: const Text('Đóng và tải bản mới'),
      ),
    ],
  );
}

/// Keeps primary actions separate from scrolling content, above the navigation bar.
class GrapActionSurface extends StatelessWidget {
  final Widget child;
  const GrapActionSurface({super.key, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      boxShadow: [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 18,
          offset: Offset(0, -3),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: child,
      ),
    ),
  );
}

class GrapIconBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  const GrapIconBadge(this.icon, {super.key, this.size = 42});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xffeaf5ee),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(icon, color: grapGreen, size: 21),
  );
}

class GrapBrandLockup extends StatelessWidget {
  final bool driver;
  const GrapBrandLockup({super.key, this.driver = false});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: grapGreen,
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(Icons.near_me_rounded, color: Colors.white, size: 23),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          driver ? 'Grap Driver' : 'Grap',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 23,
            fontWeight: FontWeight.w800,
            color: grapInk,
            letterSpacing: -.7,
          ),
        ),
      ),
    ],
  );
}
