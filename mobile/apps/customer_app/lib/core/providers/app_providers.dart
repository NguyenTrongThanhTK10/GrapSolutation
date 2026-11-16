import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/use_cases.dart';
import '../push/push_providers.dart';
import '../data/repositories.dart';
import '../domain/booking_discovery.dart';
import '../data/booking_discovery_repository.dart';
import '../data/account_repositories.dart';
import '../data/journey_repository.dart';
import '../data/statistics_repository.dart';
import '../domain/statistics.dart';
import '../domain/journey.dart';
import '../domain/models.dart';
import '../domain/repositories.dart';

import '../network/api_providers.dart';
import '../config/app_config.dart';
export '../network/api_providers.dart';
export '../config/app_config.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(ref.watch(apiClientProvider)),
);
final rideRepositoryProvider = Provider<RideRepository>(
  (ref) => ApiRideRepository(ref.watch(apiClientProvider)),
);
final driverRepositoryProvider = Provider<DriverRepository>(
  (ref) => ApiDriverRepository(ref.watch(apiClientProvider)),
);
final locationProvider = Provider<LocationProvider>(
  (ref) => DeviceLocationProvider(),
);
final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => ApiAccountRepository(ref.watch(apiClientProvider)),
);
final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => ApiOnboardingRepository(ref.watch(apiClientProvider)),
);
final recoveryRepositoryProvider = Provider<RecoveryRepository>(
  (ref) => ApiRecoveryRepository(ref.watch(apiClientProvider)),
);
final journeyRepositoryProvider = Provider<JourneyRepository>(
  (ref) => ApiJourneyRepository(ref.watch(apiClientProvider)),
);
final savedAddressesProvider = FutureProvider<List<SavedAddress>>((ref) {
  ref.watch(sessionProvider);
  return ref.watch(journeyRepositoryProvider).addresses();
});
final trustedContactsProvider = FutureProvider<TrustedContacts>((ref) {
  ref.watch(sessionProvider);
  return ref.watch(journeyRepositoryProvider).contacts();
});
final deletionRequestsProvider = FutureProvider<List<DeletionStatus>>((ref) {
  ref.watch(sessionProvider);
  return ref.watch(journeyRepositoryProvider).deletionRequests();
});
final receiptProvider = FutureProvider.family<RideReceipt, String>((ref, id) {
  ref.watch(sessionProvider);
  return ref.watch(journeyRepositoryProvider).receipt(id);
});
final profileProvider = FutureProvider<Profile>((ref) {
  ref.watch(sessionProvider);
  return ref.watch(accountRepositoryProvider).profile();
});
final ticketsProvider = FutureProvider<List<SupportTicket>>((ref) {
  ref.watch(sessionProvider);
  return ref.watch(accountRepositoryProvider).tickets();
});
final ticketProvider = FutureProvider.family<TicketDetail, String>((ref, id) {
  ref.watch(sessionProvider);
  return ref.watch(accountRepositoryProvider).ticket(id);
});
final notificationsProvider = FutureProvider<List<AppNotification>>((ref) {
  ref.watch(sessionProvider);
  return ref.watch(accountRepositoryProvider).notifications();
});
final pendingOperationsProvider = FutureProvider<List<PendingOperation>>((ref) {
  ref.watch(sessionProvider);
  return ref.watch(recoveryRepositoryProvider).pending();
});
final customerUseCasesProvider = Provider(
  (ref) => CustomerUseCases(ref.watch(rideRepositoryProvider)),
);
final driverUseCasesProvider = Provider(
  (ref) => DriverUseCases(
    ref.watch(rideRepositoryProvider),
    ref.watch(driverRepositoryProvider),
    ref.watch(locationProvider),
  ),
);
final sessionProvider = AsyncNotifierProvider<SessionController, GrapUser?>(
  SessionController.new,
);
final developmentAccountsProvider =
    FutureProvider.family<List<GrapUser>, String>(
      (ref, role) => enableDevelopmentLogin
          ? ref.watch(authRepositoryProvider).developmentAccounts(role)
          : Future.value([]),
    );
final demoMapsProvider = FutureProvider(
  (ref) => ref.watch(authRepositoryProvider).demoMaps,
);

class SessionController extends AsyncNotifier<GrapUser?> {
  @override
  Future<GrapUser?> build() {
    final subscription = ref.watch(apiClientProvider).sessionEnded.listen((_) {
      if (ref.mounted) state = const AsyncData(null);
    });
    ref.onDispose(subscription.cancel);
    return ref.watch(authRepositoryProvider).restore();
  }

  void updateProfile(Profile profile) {
    state = AsyncData(profile.user);
  }

  Future<void> developmentLogin(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).developmentLogin(id),
    );
  }

  Future<void> verify(String challenge, String code) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).verifyOtp(challenge, code),
    );
  }

  Future<OtpChallengeSnapshot> requestOtp(String phone, String appType) =>
      ref.read(authRepositoryProvider).requestOtp(phone, appType);
  Future<void> logout() async {
    try {
      await ref.read(pushCoordinatorProvider).disconnect();
      await ref.read(authRepositoryProvider).logout();
    } finally {
      state = const AsyncData(null);
    }
  }
}

final statisticsRepositoryProvider = Provider<StatisticsRepository>(
  (ref) => ApiStatisticsRepository(ref.watch(apiClientProvider)),
);
final rideStatisticsProvider = FutureProvider.autoDispose
    .family<RideStatistics, StatisticsPeriod>((ref, period) {
      final user = ref.watch(sessionProvider).value;
      if (user == null) {
        throw const Failure(
          'SESSION_REQUIRED',
          'Vui lòng đăng nhập để xem thống kê.',
        );
      }
      return ref.watch(statisticsRepositoryProvider).load(period);
    }, retry: (_, _) => null);

final bookingDiscoveryRepositoryProvider = Provider<BookingDiscoveryRepository>(
  (ref) => ApiBookingDiscoveryRepository(ref.watch(apiClientProvider)),
);
final appForegroundProvider = NotifierProvider<AppForeground, bool>(
  AppForeground.new,
);

class AppForeground extends Notifier<bool> {
  @override
  bool build() {
    final listener = AppLifecycleListener(
      onStateChange: (next) {
        state = next == AppLifecycleState.resumed;
      },
    );
    ref.onDispose(listener.dispose);
    final current = WidgetsBinding.instance.lifecycleState;
    return current == null || current == AppLifecycleState.resumed;
  }
}

final nearbyServicesProvider = StreamProvider.autoDispose
    .family<NearbyAvailability, Place>((ref, pickup) {
      final user = ref.watch(sessionProvider).value;
      if (user == null) {
        throw const Failure('SESSION_REQUIRED', 'Vui lòng đăng nhập lại.');
      }
      final foreground = ref.watch(appForegroundProvider);
      if (!foreground) return const Stream<NearbyAvailability>.empty();
      final repository = ref.watch(bookingDiscoveryRepositoryProvider);
      final stream = StreamController<NearbyAvailability>();
      var disposed = false, loading = false, pending = false;
      Timer? debounce;
      Future<void> load() async {
        if (disposed) return;
        if (loading) {
          pending = true;
          return;
        }
        loading = true;
        try {
          final result = await repository.nearby(pickup);
          if (!disposed) stream.add(result);
        } catch (error, stack) {
          if (!disposed) stream.addError(error, stack);
        } finally {
          loading = false;
          if (!disposed && pending) {
            pending = false;
            debounce ??= Timer(const Duration(milliseconds: 300), () {
              debounce = null;
              unawaited(load());
            });
          }
        }
      }

      void schedule() {
        if (disposed || debounce != null) return;
        debounce = Timer(const Duration(milliseconds: 300), () {
          debounce = null;
          unawaited(load());
        });
      }

      final subscription = repository
          .updates(pickup)
          .listen((_) => schedule(), onError: (Object _) => schedule());
      final polling = Timer.periodic(
        const Duration(seconds: 5),
        (_) => schedule(),
      );
      ref.onDispose(() {
        disposed = true;
        debounce?.cancel();
        polling.cancel();
        unawaited(subscription.cancel());
        unawaited(stream.close());
      });
      unawaited(load());
      return stream.stream;
    }, retry: (_, _) => null);
