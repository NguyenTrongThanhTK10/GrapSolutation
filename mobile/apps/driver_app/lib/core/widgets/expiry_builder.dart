import 'dart:async';

import 'package:flutter/material.dart';

class ExpiryBuilder extends StatefulWidget {
  final DateTime deadline;
  final Widget Function(int seconds) builder;
  const ExpiryBuilder({
    super.key,
    required this.deadline,
    required this.builder,
  });
  @override
  State<ExpiryBuilder> createState() => _ExpiryState();
}

class _ExpiryState extends State<ExpiryBuilder> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    widget.deadline
        .difference(DateTime.now().toUtc())
        .inSeconds
        .clamp(0, 86400),
  );
}
