import 'package:grap_driver/core/push/firebase_push_gateway.dart';
import 'package:grap_driver/core/push/push_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grap_driver/app/grap_app.dart';
import 'package:grap_driver/features/auth/presentation/auth_gate.dart';

import 'features/driving/driver_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final gateway = await initializeFirebasePush();
  runApp(
    ProviderScope(
      overrides: [pushGatewayProvider.overrideWithValue(gateway)],
      child: const DriverApp(),
    ),
  );
}

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});
  @override
  Widget build(BuildContext context) => GrapMaterialApp(
    title: 'Grap · Đối tác tài xế',
    home: AuthGate(
      role: 'Driver',
      title: 'Cùng thành phố\nchuyển động.',
      builder: (user) => DriverScreen(user: user),
    ),
  );
}
