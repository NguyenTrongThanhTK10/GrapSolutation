import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grap_driver/core/core.dart';
import 'package:grap_driver/core/application/load_result.dart';

class DriverViewState {
  final Availability? availability;
  final DriverOffer? offer;
  final RideSnapshot? ride;
  final Earnings? earnings;
  final List<RideSnapshot> history;
  final List<Place> places;
  final Place? developmentPlace;
  final bool busy, demo;
  final bool paymentNeedsRefresh;
  final String? error, message;
  const DriverViewState({
    this.availability,
    this.offer,
    this.ride,
    this.earnings,
    this.history = const [],
    this.places = const [],
    this.developmentPlace,
    this.busy = false,
    this.demo = false,
    this.paymentNeedsRefresh = false,
    this.error,
    this.message,
  });
  DriverViewState copyWith({
    Availability? availability,
    DriverOffer? offer,
    RideSnapshot? ride,
    Earnings? earnings,
    List<RideSnapshot>? history,
    Place? developmentPlace,
    bool? busy,
    bool? paymentNeedsRefresh,
    String? error,
    String? message,
    bool clearOffer = false,
    bool clearRide = false,
  }) => DriverViewState(
    availability: availability ?? this.availability,
    offer: clearOffer ? null : offer ?? this.offer,
    ride: clearRide ? null : ride ?? this.ride,
    earnings: earnings ?? this.earnings,
    history: history ?? this.history,
    places: places,
    developmentPlace: developmentPlace ?? this.developmentPlace,
    busy: busy ?? this.busy,
    paymentNeedsRefresh: paymentNeedsRefresh ?? this.paymentNeedsRefresh,
    demo: demo,
    error: error,
    message: message,
  );
}

final driverControllerProvider =
    AsyncNotifierProvider<DriverController, DriverViewState>(
      DriverController.new,
    );

class DriverController extends AsyncNotifier<DriverViewState> {
  int _generation = 0, _revision = 0;
  int? _publishingGeneration, _refreshGeneration;
  bool _foreground = true;
  DateTime? _supplementalAt;
  String? _supplementalWarning;
  @override
  Future<DriverViewState> build() async {
    final user = ref.watch(sessionProvider).value;
    final generation = ++_generation;
    _supplementalAt = null;
    _supplementalWarning = null;
    if (user == null) return const DriverViewState();
    final rides = ref.watch(rideRepositoryProvider),
        drivers = ref.watch(driverRepositoryProvider);
    final subscription = rides.updates().listen((_) {
      if (generation == _generation && _foreground) {
        unawaited(refresh(forceSupplemental: false));
      }
    });
    final timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (generation == _generation &&
          _foreground &&
          state.value?.availability?.online == true) {
        unawaited(publishLocation());
      }
    });
    ref.onDispose(() {
      subscription.cancel();
      timer.cancel();
    });
    final results = await Future.wait<Object?>([
      rides.active(),
      LoadResult.capture(drivers.availability),
      LoadResult.capture(drivers.currentOffer),
      LoadResult.capture(drivers.earnings),
      LoadResult.capture(rides.history),
      LoadResult.capture(
        () async =>
            enableDevelopmentLogin &&
            await ref.read(authRepositoryProvider).demoMaps,
      ),
    ]);
    final ride = results[0] as RideSnapshot?;
    final availability = results[1] as LoadResult<Availability>;
    final offer = results[2] as LoadResult<DriverOffer?>;
    final earnings = results[3] as LoadResult<Earnings>;
    final history = results[4] as LoadResult<List<RideSnapshot>>;
    final config = results[5] as LoadResult<bool>;
    final demo = config.or(false);
    final places = demo
        ? await LoadResult.capture(() => rides.places(''))
        : const LoadResult<List<Place>>.value([]);
    final supplementalWarning = loadingWarning({
      'thu nhập': earnings.error,
      'lịch sử': history.error,
    });
    if (generation == _generation) {
      _supplementalAt = DateTime.now();
      _supplementalWarning = supplementalWarning;
    }
    return DriverViewState(
      availability: availability.value,
      ride: ride,
      offer: offer.value,
      earnings: earnings.value,
      history: history.or([]),
      demo: demo,
      places: places.or([]),
      developmentPlace: places.or([]).firstOrNull,
      error: loadingWarning({
        'trạng thái nhận chuyến': availability.error,
        'lời mời': offer.error,
        'thu nhập': earnings.error,
        'lịch sử': history.error,
        'cấu hình': config.error,
        'địa điểm': places.error,
      }),
    );
  }

  void setForeground(bool active) {
    _foreground = active;
    if (active) unawaited(refresh());
  }

  PositionEvidence? _position(DriverViewState s) {
    final p = s.developmentPlace;
    if (!s.demo || p == null) return null;
    return PositionEvidence(
      latitude: p.latitude,
      longitude: p.longitude,
      accuracy: 15,
      recordedAt: DateTime.now().toUtc(),
      sequence: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void choosePlace(Place place) {
    _revision++;
    final s = state.value;
    if (s != null) state = AsyncData(s.copyWith(developmentPlace: place));
  }

  Future<void> _command(
    Future<DriverViewState> Function(DriverViewState) work,
  ) async {
    final current = state.value;
    if (current == null || current.busy) return;
    final generation = _generation;
    _revision++;
    state = AsyncData(current.copyWith(busy: true));
    try {
      final result = await work(current);
      if (ref.mounted && generation == _generation) {
        if (result.ride?.id != current.ride?.id ||
            result.ride?.version != current.ride?.version) {
          _supplementalAt = null;
        }
        state = AsyncData(
          result.copyWith(
            busy: false,
            message: result.message,
            error: result.error,
          ),
        );
      }
    } catch (e) {
      if (ref.mounted && generation == _generation) {
        state = AsyncData(current.copyWith(busy: false, error: e.toString()));
        if (e is Failure &&
            [
              'VERSION_CONFLICT',
              'INVALID_RIDE_STATE',
              'OFFER_EXPIRED',
              'OFFER_NOT_AVAILABLE',
            ].contains(e.code)) {
          await refresh();
        }
      }
    } finally {
      if (ref.mounted) ref.invalidate(pendingOperationsProvider);
    }
  }

  Future<void> refresh({bool forceSupplemental = true}) async {
    if (_refreshGeneration == _generation ||
        state.value == null ||
        state.value!.busy) {
      return;
    }
    final generation = _generation;
    _refreshGeneration = generation;
    final revision = _revision;
    try {
      final rides = ref.read(rideRepositoryProvider),
          drivers = ref.read(driverRepositoryProvider);
      final primary = await Future.wait<Object?>([
        rides.active(),
        LoadResult.capture(drivers.availability),
        LoadResult.capture(drivers.currentOffer),
      ]);
      final active = primary[0] as RideSnapshot?;
      final availability = primary[1] as LoadResult<Availability>;
      final offer = primary[2] as LoadResult<DriverOffer?>;
      if (!ref.mounted ||
          generation != _generation ||
          revision != _revision ||
          state.value == null ||
          state.value!.busy) {
        return;
      }
      final before = state.value!;
      final changed = active == null
          ? before.ride?.active == true
          : before.ride?.id != active.id ||
                before.ride?.version != active.version;
      final loadExtra =
          forceSupplemental ||
          changed ||
          _supplementalAt == null ||
          DateTime.now().difference(_supplementalAt!) >=
              const Duration(seconds: 30);
      var history = before.history;
      var earnings = before.earnings;
      var supplementalWarning = _supplementalWarning;
      bool freshHistory = false;
      if (loadExtra) {
        final extras = await Future.wait<Object?>([
          LoadResult.capture(rides.history),
          LoadResult.capture(drivers.earnings),
        ]);
        final h = extras[0] as LoadResult<List<RideSnapshot>>;
        final e = extras[1] as LoadResult<Earnings>;
        history = h.or(history);
        earnings = e.value ?? earnings;
        freshHistory = h.error == null;
        supplementalWarning = loadingWarning({
          'thu nhập': e.error,
          'lịch sử': h.error,
        });
      }
      if (!ref.mounted ||
          generation != _generation ||
          revision != _revision ||
          state.value!.busy) {
        return;
      }
      final s = state.value!;
      var shown =
          active ?? history.where((r) => r.id == s.ride?.id).firstOrNull;
      if (active == null && shown?.active == true) shown = null;
      var paymentNeedsRefresh =
          s.paymentNeedsRefresh &&
          active == null &&
          !(freshHistory && shown != null);
      String? paymentWarning;
      if (paymentNeedsRefresh && s.ride != null) {
        final detail = await LoadResult.capture(() => rides.detail(s.ride!.id));
        if (detail.error == null) {
          shown = detail.value;
          paymentNeedsRefresh = false;
        } else {
          paymentWarning = 'Đã ghi nhận tiền mặt; chưa tải được số tiền còn lại. Kéo xuống để kiểm tra.';
        }
      }
      if (shown == null && s.ride != null) {
        if (!s.ride!.active) {
          shown = s.ride;
        } else {
          try {
            shown = await rides.detail(s.ride!.id);
          } on Failure catch (e) {
            if (!const ['RESOURCE_NOT_FOUND', 'HTTP_404'].contains(e.code)) {
              rethrow;
            }
            history = history
                .where((r) => r.id != s.ride!.id || !r.active)
                .toList();
          }
        }
      }
      if (!ref.mounted ||
          generation != _generation ||
          revision != _revision ||
          state.value!.busy) {
        return;
      }
      state = AsyncData(
        s.copyWith(
          availability: availability.value,
          ride: shown,
          clearRide: shown == null,
          offer: offer.or(s.offer),
          clearOffer: offer.error == null && offer.value == null,
          history: history,
          earnings: earnings,
          paymentNeedsRefresh: paymentNeedsRefresh,
          error: combineWarnings([
            loadingWarning({
              'trạng thái nhận chuyến': availability.error,
              'lời mời': offer.error,
            }),
            supplementalWarning,
            paymentWarning,
          ]),
        ),
      );
      if (loadExtra) {
        _supplementalAt = DateTime.now();
        _supplementalWarning = supplementalWarning;
      }
    } catch (e) {
      if (ref.mounted &&
          generation == _generation &&
          revision == _revision &&
          state.value != null) {
        state = AsyncData(state.value!.copyWith(error: e.toString()));
      }
    } finally {
      if (_refreshGeneration == generation) _refreshGeneration = null;
    }
  }

  Future<void> toggle(bool online) => _command((s) async {
    if (s.availability == null) return s;
    final drivers = ref.read(driverRepositoryProvider);
    await drivers.setOnline(s.availability!, online);
    final availability = await drivers.availability();
    if (online) {
      try {
        await ref
            .read(driverUseCasesProvider)
            .publishPosition(developmentPosition: _position(s));
      } catch (e) {
        return s.copyWith(availability: availability, error: e.toString());
      }
    }
    return s.copyWith(availability: availability);
  });
  Future<void> publishLocation() async {
    final current = state.value;
    if (current == null ||
        _publishingGeneration == _generation ||
        current.availability?.online != true ||
        !_foreground) {
      return;
    }
    final generation = _generation;
    _publishingGeneration = generation;
    final useCases = ref.read(driverUseCasesProvider);
    try {
      await useCases.publishPosition(developmentPosition: _position(current));
    } catch (e) {
      if (ref.mounted &&
          generation == _generation &&
          state.value != null &&
          !state.value!.busy) {
        state = AsyncData(state.value!.copyWith(error: e.toString()));
      }
    } finally {
      if (_publishingGeneration == generation) _publishingGeneration = null;
    }
  }

  Future<void> recordContact(String note) => _command((s) async {
    if (s.ride != null) {
      await ref
          .read(driverRepositoryProvider)
          .recordContactAttempt(s.ride!, 'PHONE', note);
    }
    return s.copyWith(message: 'Đã ghi nhận lần thử liên hệ.');
  });
  Future<void> noShow(String reason) => _command(
    (s) async => s.ride == null
        ? s
        : s.copyWith(
            ride: await ref
                .read(rideRepositoryProvider)
                .command(s.ride!, 'no-show', reason: reason),
          ),
  );
  Future<void> endEarly(String reason) => _command((s) async {
    if (s.ride == null) return s;
    final rides = ref.read(rideRepositoryProvider),
        locator = ref.read(locationProvider);
    final location = _position(s) ?? await locator.current();
    return s.copyWith(
      ride: await rides.command(
        s.ride!,
        'complete',
        reason: reason,
        position: location,
        completionType: 'EARLY',
      ),
    );
  });
  Future<void> accept() => _command(
    (s) async => s.offer == null
        ? s
        : s.copyWith(
            ride: await ref.read(driverRepositoryProvider).accept(s.offer!),
            clearOffer: true,
          ),
  );
  Future<void> reject() => _command((s) async {
    if (s.offer != null) {
      await ref.read(driverRepositoryProvider).reject(s.offer!);
    }
    return s.copyWith(clearOffer: true);
  });
  Future<void> arrive() => _command(
    (s) async => s.ride == null
        ? s
        : s.copyWith(
            ride: await ref
                .read(driverUseCasesProvider)
                .arrive(s.ride!, developmentPosition: _position(s)),
          ),
  );
  Future<void> start(String pin) => _command(
    (s) async => s.ride == null
        ? s
        : s.copyWith(
            ride: await ref.read(driverUseCasesProvider).start(s.ride!, pin),
          ),
  );
  Future<void> complete() => _command(
    (s) async => s.ride == null
        ? s
        : s.copyWith(
            ride: await ref
                .read(driverUseCasesProvider)
                .complete(s.ride!, developmentPosition: _position(s)),
          ),
  );
  Future<void> cash(int amount, String reason) => _command((s) async {
    if (s.ride?.payment == null) return s;
    final pending = await ref.read(recoveryRepositoryProvider).pending();
    if (pending.any(
      (p) => p.path == '/payments/${s.ride!.payment!.id}/cash-collections',
    )) {
      throw const Failure(
        'PAYMENT_CONFIRMATION_PENDING',
        'Có thao tác thu tiền chưa xác nhận. Hãy kiểm tra hoặc gửi lại thao tác đang chờ trước khi thu thêm.',
      );
    }
    if (s.paymentNeedsRefresh) {
      throw const Failure(
        'PAYMENT_REFRESH_REQUIRED',
        'Cần tải lại trạng thái thanh toán trước khi thu thêm.',
      );
    }
    final rides = ref.read(rideRepositoryProvider);
    await rides.cash(s.ride!.payment!, amount, reason);
    final results = await Future.wait<Object?>([
      LoadResult.capture(() => rides.detail(s.ride!.id)),
      LoadResult.capture(rides.history),
      LoadResult.capture(ref.read(driverRepositoryProvider).earnings),
    ]);
    final updated = results[0] as LoadResult<RideSnapshot>;
    final history = results[1] as LoadResult<List<RideSnapshot>>;
    final earnings = results[2] as LoadResult<Earnings>;
    return s.copyWith(
      ride: updated.value,
      paymentNeedsRefresh: updated.error != null,
      history: history.or(s.history),
      earnings: earnings.value,
      error: loadingWarning({
        'chi tiết thanh toán': updated.error,
        'lịch sử': history.error,
        'thu nhập': earnings.error,
      }),
      message: 'Đã ghi nhận tiền mặt. Chuyến và khoản thu được lưu độc lập.',
    );
  });
  Future<void> release(String reason) => _command((s) async {
    if (s.ride != null) {
      await ref
          .read(rideRepositoryProvider)
          .command(s.ride!, 'release-assignment', reason: reason);
    }
    return s.copyWith(clearRide: true);
  });
  Future<void> support(String text) => _command((s) async {
    await ref.read(rideRepositoryProvider).support(text, rideId: s.ride?.id);
    return s.copyWith(message: 'Đã gửi yêu cầu hỗ trợ.');
  });
  Future<void> sos() => _command(
    (s) async => s.ride == null
        ? s
        : s.copyWith(
            message: await ref.read(rideRepositoryProvider).sos(s.ride!),
          ),
  );
  void viewRide(RideSnapshot ride) {
    final s = state.value;
    if (s != null) state = AsyncData(s.copyWith(ride: ride));
  }

  void dismissRide() {
    final s = state.value;
    if (s?.ride != null && !s!.ride!.active) {
      state = AsyncData(s.copyWith(clearRide: true));
    }
  }
}
