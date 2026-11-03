import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grap_driver/core/core.dart';
import 'package:grap_driver/core/push/push_providers.dart';
import 'package:grap_driver/core/theme/app_theme.dart';
import 'package:grap_driver/features/account/presentation/account_screens.dart';
import 'package:grap_driver/features/journey/presentation/journey_screens.dart';

class GrapMaterialApp extends ConsumerStatefulWidget {
  final String title;
  final Widget home;
  const GrapMaterialApp({super.key, required this.title, required this.home});
  @override
  ConsumerState<GrapMaterialApp> createState() => _GrapMaterialAppState();
}

class _GrapMaterialAppState extends ConsumerState<GrapMaterialApp>
    with WidgetsBindingObserver {
  final navigator = GlobalKey<NavigatorState>();
  final messenger = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<PushEvent>? messages;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final push = ref.read(pushCoordinatorProvider);
    messages = push.events.listen(_receive);
    ref.listenManual(sessionProvider, (previous, next) {
      if (!next.isLoading) unawaited(push.bind(next.value?.id));
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(messages?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed)
      unawaited(ref.read(pushCoordinatorProvider).synchronize());
  }

  void _receive(PushEvent event) {
    if (!mounted || ref.read(sessionProvider).value?.id != event.message.userId)
      return;
    ref.invalidate(notificationsProvider);
    if (event.message.kind == 'ticket') {
      ref.invalidate(ticketsProvider);
      ref.invalidate(ticketProvider(event.message.entityId));
    }
    ref.read(pushIntentProvider.notifier).receive(event);
    if (event.opened) {
      unawaited(_open(event.message));
    } else {
      messenger.currentState?.showSnackBar(
        SnackBar(
          content: const Text('Grap có thông báo mới.'),
          action: SnackBarAction(
            label: 'Xem',
            onPressed: () => unawaited(_open(event.message)),
          ),
        ),
      );
    }
  }

  Future<void> _open(PushMessage message) async {
    final scope = ref.read(apiClientProvider).sessionScope;
    if (ref.read(sessionProvider).value?.id != message.userId) return;
    try {
      // Verify ownership on the API before navigating from externally supplied notification data.
      await ref.read(accountRepositoryProvider).markRead(message.id);
      if (!mounted ||
          scope != ref.read(apiClientProvider).sessionScope ||
          ref.read(sessionProvider).value?.id != message.userId)
        return;
      ref.invalidate(notificationsProvider);
      final nav = navigator.currentState;
      if (nav == null) return;
      if (message.kind == 'offer') {
        nav.popUntil((route) => route.isFirst);
        ref
            .read(pushIntentProvider.notifier)
            .receive(PushEvent(message, opened: true));
      } else if (message.kind == 'ride' && message.entityId.isNotEmpty) {
        unawaited(
          nav.push<void>(
            MaterialPageRoute(
              builder: (_) => RideReceiptScreen(rideId: message.entityId),
            ),
          ),
        );
      } else if (message.kind == 'ticket' && message.entityId.isNotEmpty) {
        unawaited(
          nav.push<void>(
            MaterialPageRoute(
              builder: (_) => TicketScreen(ticketId: message.entityId),
            ),
          ),
        );
      } else {
        unawaited(
          nav.push<void>(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        );
      }
    } catch (_) {
      if (mounted && scope == ref.read(apiClientProvider).sessionScope)
        messenger.currentState?.showSnackBar(
          const SnackBar(
            content: Text(
              'Không mở được thông báo. Hãy kiểm tra kết nối hoặc đăng nhập lại.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (previous, next) {
      if (next.isLoading) return;
      final before = previous?.value?.id, after = next.value?.id;
      if (before != null && before != after)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted)
            navigator.currentState?.popUntil((route) => route.isFirst);
        });
    });
    return MaterialApp(
      navigatorKey: navigator,
      scaffoldMessengerKey: messenger,
      title: widget.title,
      debugShowCheckedModeBanner: false,
      theme: grapTheme(),
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: widget.home,
    );
  }
}
