import 'package:grap_customer/core/push/firebase_push_gateway.dart';
import 'package:grap_customer/core/push/push_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grap_customer/app/grap_app.dart';
import 'package:grap_customer/features/auth/presentation/auth_gate.dart';

import 'features/booking/customer_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final gateway = await initializeFirebasePush();
  runApp(
    ProviderScope(
      overrides: [pushGatewayProvider.overrideWithValue(gateway)],
      child: const CustomerApp(),
    ),
  );
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});
  @override
  Widget build(BuildContext context) => GrapMaterialApp(
    title: 'Grap · Khách hàng',
    home: AuthGate(
      role: 'Customer',
      title: 'Chuyển động\ncùng thành phố.',
      builder: (user) => CustomerScreen(user: user),
    ),
  );
}
