import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grap_customer/core/core.dart';
import 'package:grap_customer/core/application/load_result.dart';

class CustomerState {
  final List<Place> places;
  final List<RideSnapshot> history;
  final Place? pickup, dropoff;
  final String service;
  final QuoteSnapshot? quote;
  final Map<String, QuoteSnapshot> quoteOptions;
  final Map<String, String> quoteErrors;
  final bool pricing;
  final RideSnapshot? ride;
  final bool busy, demo;
  final String? error, message;
  const CustomerState({
    this.places = const [],
    this.history = const [],
    this.pickup,
    this.dropoff,
    this.service = 'BIKE',
    this.quote,
    this.quoteOptions = const {},
    this.quoteErrors = const {},
    this.pricing = false,
    this.ride,
    this.busy = false,
    this.demo = false,
    this.error,
    this.message,
  });
  CustomerState copyWith({
    List<RideSnapshot>? history,
    List<Place>? places,
    Place? pickup,
    Place? dropoff,
    String? service,
    QuoteSnapshot? quote,
    Map<String, QuoteSnapshot>? quoteOptions,
    Map<String, String>? quoteErrors,
    bool? pricing,
    bool clearPrices = false,
    RideSnapshot? ride,
    bool? busy,
    bool? demo,
    String? error,
    String? message,
    bool clearQuote = false,
    bool clearRide = false,
  }) => CustomerState(
    places: places ?? this.places,
    history: history ?? this.history,
    pickup: pickup ?? this.pickup,
    dropoff: dropoff ?? this.dropoff,
    service: service ?? this.service,
    quote: clearQuote || clearPrices ? null : quote ?? this.quote,
    quoteOptions: clearPrices ? const {} : quoteOptions ?? this.quoteOptions,
    quoteErrors: clearPrices ? const {} : quoteErrors ?? this.quoteErrors,
    pricing: pricing ?? this.pricing,
    ride: clearRide ? null : ride ?? this.ride,
    busy: busy ?? this.busy,
    demo: demo ?? this.demo,
    error: error,
    message: message,
  );
}

final customerControllerProvider =
    AsyncNotifierProvider<CustomerController, CustomerState>(
      CustomerController.new,
    );

class CustomerController extends AsyncNotifier<CustomerState> {
  int _generation = 0, _revision = 0, _priceRevision = 0;
  int? _refreshGeneration;
  DateTime? _supplementalAt;
  String? _supplementalWarning;
  bool _foreground = true;
  void setForeground(bool active) {
    _foreground = active;
    if (active) unawaited(refresh());
  }

  @override
  Future<CustomerState> build() async {
    final user = ref.watch(sessionProvider).value;
    final generation = ++_generation;
    _priceRevision++;
    _supplementalAt = null;
    _supplementalWarning = null;
    if (user == null) return const CustomerState();
    final repository = ref.watch(rideRepositoryProvider);
    final subscription = repository.updates().listen((_) {
      if (generation == _generation && _foreground) {
        unawaited(refresh(forceSupplemental: false));
      }
    });
    ref.onDispose(subscription.cancel);
    final config = LoadResult.capture(
      () => ref.read(authRepositoryProvider).demoMaps,
    );
    final results = await Future.wait<Object?>([
      repository.active(),
      config.then(
        (result) => result.or(false)
            ? LoadResult.capture(() => repository.places(''))
            : const LoadResult<List<Place>>.value([]),
      ),
      LoadResult.capture(repository.history),
      config,
    ]);
    final active = results[0] as RideSnapshot?;
    final placesResult = results[1] as LoadResult<List<Place>>;
    final historyResult = results[2] as LoadResult<List<RideSnapshot>>;
    final configResult = results[3] as LoadResult<bool>;
    final places = placesResult.or([]);
    final warning = loadingWarning({
      'địa điểm': placesResult.error,
      'lịch sử': historyResult.error,
      'cấu hình': configResult.error,
    });
    if (generation == _generation) {
      _supplementalAt = DateTime.now();
      _supplementalWarning = warning;
    }
    return CustomerState(
      places: places,
      pickup: configResult.or(false) ? places.firstOrNull : null,
      dropoff: configResult.or(false) && places.length > 1 ? places[1] : null,
      ride: active,
      history: historyResult.or([]),
      demo: configResult.or(false),
      error: warning,
    );
  }

  void selectPickup(Place p) {
    _revision++;
    _priceRevision++;
    final s = state.value;
    if (s != null && !s.busy) {
      state = AsyncData(
        s.copyWith(
          pickup: p,
          places: [...s.places.where((x) => x.id != p.id), p],
          clearPrices: true,
          pricing: false,
        ),
      );
    }
  }

  void selectDropoff(Place p) {
    _revision++;
    _priceRevision++;
    final s = state.value;
    if (s != null && !s.busy) {
      state = AsyncData(
        s.copyWith(
          dropoff: p,
          places: [...s.places.where((x) => x.id != p.id), p],
          clearPrices: true,
          pricing: false,
        ),
      );
    }
  }

  void selectService(String value) {
    if (!const ['BIKE', 'CAR_4', 'CAR_7'].contains(value)) return;
    _revision++;
    final s = state.value;
    if (s != null && !s.busy) {
      state = AsyncData(
        s.copyWith(
          service: value,
          quote: s.quoteOptions[value],
          clearQuote: s.quoteOptions[value] == null,
          error: s.quoteErrors[value],
        ),
      );
    }
  }

  Future<void> _command(
    Future<CustomerState> Function(CustomerState) work,
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
          result.copyWith(busy: false, message: result.message),
        );
      }
    } catch (e) {
      if (ref.mounted && generation == _generation) {
        state = AsyncData(current.copyWith(busy: false, error: e.toString()));
        if (e is Failure &&
            [
              'ACTIVE_RIDE_EXISTS',
              'VERSION_CONFLICT',
              'INVALID_RIDE_STATE',
            ].contains(e.code)) {
          await refresh();
        }
      }
    } finally {
      if (ref.mounted) ref.invalidate(pendingOperationsProvider);
    }
  }

  void swapPlaces() {
    final s = state.value;
    if (s == null ||
        s.busy ||
        s.pickup == null ||
        s.dropoff == null ||
        s.ride?.active == true) {
      return;
    }
    _revision++;
    _priceRevision++;
    state = AsyncData(
      s.copyWith(
        pickup: s.dropoff,
        dropoff: s.pickup,
        clearPrices: true,
        pricing: false,
      ),
    );
  }

  Future<void> quote() async {
    final s = state.value;
    if (s == null || s.busy || s.pricing || s.ride?.active == true) return;
    if (s.pickup == null || s.dropoff == null) {
      state = AsyncData(
        s.copyWith(error: 'Vui lòng chọn điểm đón và điểm đến.'),
      );
      return;
    }
    final generation = _generation, priceRevision = ++_priceRevision;
    _revision++;
    state = AsyncData(s.copyWith(pricing: true, clearPrices: true));
    const codes = ['BIKE', 'CAR_4', 'CAR_7'];
    late List<LoadResult<QuoteSnapshot>> results;
    try {
      results = await Future.wait([
        for (final code in codes)
          LoadResult.capture(
            () => ref
                .read(customerUseCasesProvider)
                .quote(s.pickup!, s.dropoff!, code),
          ),
      ]);
    } catch (e) {
      if (ref.mounted &&
          generation == _generation &&
          priceRevision == _priceRevision &&
          state.value != null) {
        state = AsyncData(
          state.value!.copyWith(
            pricing: false,
            clearPrices: true,
            error: e.toString(),
          ),
        );
      }
      return;
    }
    if (!ref.mounted ||
        generation != _generation ||
        priceRevision != _priceRevision ||
        state.value == null) {
      return;
    }
    final options = <String, QuoteSnapshot>{}, errors = <String, String>{};
    for (var i = 0; i < codes.length; i++) {
      final result = results[i];
      if (result.value != null) {
        options[codes[i]] = result.value!;
      } else {
        errors[codes[i]] = result.error.toString();
      }
    }
    final current = state.value!;
    if (current.ride?.active == true) {
      state = AsyncData(current.copyWith(pricing: false, clearPrices: true));
      return;
    }
    state = AsyncData(
      current.copyWith(
        pricing: false,
        quoteOptions: options,
        quoteErrors: errors,
        quote: options[current.service],
        clearQuote: !options.containsKey(current.service),
        error: errors[current.service],
      ),
    );
  }

  Future<void> book() => _command((s) async {
    if (s.pricing) {
      throw const Failure('QUOTE_PENDING', 'Đang so sánh giá. Vui lòng chờ.');
    }
    if (s.quote == null) {
      throw const Failure('QUOTE_REQUIRED', 'Vui lòng xem giá trước khi đặt.');
    }
    return s.copyWith(
      ride: await ref.read(customerUseCasesProvider).book(s.quote!),
      clearQuote: true,
    );
  });
  Future<void> cancel(String reason) => _command(
    (s) async => s.ride == null
        ? s
        : s.copyWith(
            ride: await ref
                .read(customerUseCasesProvider)
                .cancel(s.ride!, reason),
          ),
  );
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
      final repository = ref.read(rideRepositoryProvider);
      final active = await repository.active();
      final before = state.value;
      if (!ref.mounted ||
          generation != _generation ||
          revision != _revision ||
          before == null ||
          before.busy) {
        return;
      }
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
      var places = before.places;
      var demo = before.demo;
      var warning = _supplementalWarning;
      if (loadExtra) {
        final extras = await Future.wait<Object?>([
          LoadResult.capture(repository.history),
          if (forceSupplemental && places.isEmpty && demo)
            LoadResult.capture(() => repository.places('')),
          if (forceSupplemental)
            LoadResult.capture(() => ref.read(authRepositoryProvider).demoMaps),
        ]);
        final historyResult = extras[0] as LoadResult<List<RideSnapshot>>;
        final errors = <String, Object?>{'lịch sử': historyResult.error};
        history = historyResult.or(history);
        var index = 1;
        if (forceSupplemental && places.isEmpty && demo) {
          final result = extras[index++] as LoadResult<List<Place>>;
          places = result.or(places);
          errors['địa điểm'] = result.error;
        }
        if (forceSupplemental) {
          final result = extras[index] as LoadResult<bool>;
          demo = result.or(demo);
          errors['cấu hình'] = result.error;
        }
        warning = loadingWarning(errors);
      }
      if (!ref.mounted ||
          generation != _generation ||
          revision != _revision ||
          state.value!.busy) {
        return;
      }
      final current = state.value!;
      var shown =
          active ?? history.where((r) => r.id == current.ride?.id).firstOrNull;
      // A cached active history item cannot overrule the active endpoint.
      if (active == null && shown?.active == true) shown = null;
      if (shown == null && current.ride != null) {
        if (!current.ride!.active) {
          shown = current.ride;
        } else {
          try {
            shown = await repository.detail(current.ride!.id);
          } on Failure catch (e) {
            if (!const ['RESOURCE_NOT_FOUND', 'HTTP_404'].contains(e.code)) {
              rethrow;
            }
            history = history
                .where((r) => r.id != current.ride!.id || !r.active)
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
        state.value!.copyWith(
          ride: shown,
          clearRide: shown == null,
          history: history,
          places: places,
          demo: demo,
          error: warning,
        ),
      );
      if (loadExtra) {
        _supplementalAt = DateTime.now();
        _supplementalWarning = warning;
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

  void newBooking() {
    final s = state.value;
    if (s != null && !s.busy && s.ride?.active != true) {
      _revision++;
      _priceRevision++;
      state = AsyncData(
        s.copyWith(clearRide: true, clearPrices: true, pricing: false),
      );
    }
  }

  void rebook(RideSnapshot ride) {
    final s = state.value;
    if (s == null || s.busy) return;
    if (s.ride?.active == true) {
      state = AsyncData(
        s.copyWith(
          error: 'Bạn đang có chuyến chưa kết thúc. Vui lòng hoàn tất chuyến trước khi đặt lại.',
        ),
      );
      return;
    }
    _revision++;
    _priceRevision++;
    final byId = {
      for (final p in s.places) p.id: p,
      ride.pickup.id: ride.pickup,
      ride.dropoff.id: ride.dropoff,
    };
    state = AsyncData(
      s.copyWith(
        clearRide: true,
        clearPrices: true,
        pricing: false,
        pickup: ride.pickup,
        dropoff: ride.dropoff,
        service: ride.service,
        places: byId.values.toList(),
      ),
    );
  }

  void viewRide(RideSnapshot ride) {
    final s = state.value;
    if (s != null) state = AsyncData(s.copyWith(ride: ride));
  }

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
  Future<void> share() => _command(
    (s) async => s.ride == null
        ? s
        : s.copyWith(
            message: await ref.read(rideRepositoryProvider).share(s.ride!),
          ),
  );
  Future<void> rate(int stars, String comment) => _command((s) async {
    if (s.ride == null) return s;
    await ref.read(rideRepositoryProvider).rate(s.ride!, stars, comment);
    return s.copyWith(message: 'Cảm ơn bạn đã đánh giá hành trình!');
  });
}
