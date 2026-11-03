import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/api_providers.dart';
import 'push_coordinator.dart';
import 'push_models.dart';
export 'push_models.dart';

final pushGatewayProvider = Provider<PushGateway>(
  (ref) => const DisabledPushGateway(),
);
final pushCoordinatorProvider = Provider<PushCoordinator>((ref) {
  final service = PushCoordinator(
    ref.watch(apiClientProvider),
    const FlutterSecureStorage(),
    ref.watch(pushGatewayProvider),
    'customer',
  );
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});
final pushStatusProvider = StreamProvider<PushStatus>((ref) async* {
  final service = ref.watch(pushCoordinatorProvider);
  yield service.status;
  yield* service.statuses;
});

class PushIntent extends Notifier<PushEvent?> {
  @override
  PushEvent? build() => null;
  void receive(PushEvent event) => state = event;
}

final pushIntentProvider = NotifierProvider<PushIntent, PushEvent?>(
  PushIntent.new,
);
