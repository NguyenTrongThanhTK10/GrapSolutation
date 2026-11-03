import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import '../domain/repositories.dart';
import '../network/api_client.dart';
import 'mappers.dart';

DateTime deadlineFromJson(Json j, String key) {
  final deadline = DateTime.parse(j[key] as String);
  final server = j['serverTime'] as String?;
  return server == null
      ? deadline
      : DateTime.now().toUtc().add(deadline.difference(DateTime.parse(server)));
}

class ApiAuthRepository implements AuthRepository {
  final ApiClient _client;
  ApiAuthRepository(this._client);
  @override
  Future<GrapUser?> restore() async {
    final session = await _client.restore();
    return session == null ? null : userFromJson(session['user'] as Json);
  }

  @override
  Future<List<GrapUser>> developmentAccounts(String role) async {
    final accounts =
        await _client.request('/auth/development/accounts') as List;
    return accounts
        .map((j) => userFromJson(j as Json))
        .where((u) => u.role == role)
        .toList();
  }

  @override
  Future<GrapUser> developmentLogin(String userId) async {
    final session = await _client.request(
      '/auth/development',
      method: 'POST',
      body: {'userId': userId, 'deviceId': const Uuid().v4()},
    ) as Json;
    await _client.save(session);
    return userFromJson(session['user'] as Json);
  }

  @override
  Future<OtpChallengeSnapshot> requestOtp(String phone, String appType) async {
    final result = await _client.request(
      '/auth/otp/challenges',
      method: 'POST',
      body: {'phone': phone, 'appType': appType},
    ) as Json;
    return OtpChallengeSnapshot(
      id: result['challengeId'] as String,
      expiresAt: deadlineFromJson(result, 'expiresAt'),
      resendAt: DateTime.now().toUtc().add(
        Duration(seconds: (result['resendAfter'] as num).toInt()),
      ),
    );
  }

  @override
  Future<GrapUser> verifyOtp(String challengeId, String code) async {
    final session = await _client.request(
      '/auth/otp/verify',
      method: 'POST',
      body: {
        'challengeId': challengeId,
        'otp': code,
        'deviceId': const Uuid().v4(),
      },
    ) as Json;
    await _client.save(session);
    return userFromJson(session['user'] as Json);
  }

  @override
  Future<void> logout() async {
    try {
      await _client.request('/auth/logout', method: 'POST');
    } finally {
      await _client.clear();
    }
  }

  @override
  Future<bool> get demoMaps async =>
      ((await _client.request('/app-config') as Json)['featureFlags']
              as Json)['demoMaps']
          as bool;
}

class ApiRideRepository implements RideRepository {
  final ApiClient _client;
  ApiRideRepository(this._client);
  @override
  Future<RideSnapshot> detail(String id) async =>
      rideFromJson(await _client.request('/rides/$id') as Json);
  @override
  Future<RideSnapshot?> active() async {
    final j = await _client.request('/rides/active') as Json;
    return j['ride'] == null ? null : rideFromJson(j['ride'] as Json);
  }

  @override
  Future<List<RideSnapshot>> history() async {
    final j = await _client.request('/rides?pageSize=20') as Json;
    return (j['items'] as List).map((r) => rideFromJson(r as Json)).toList();
  }

  @override
  Future<List<Place>> places(String query) async {
    final j = await _client.request(
      '/places/autocomplete?q=${Uri.encodeQueryComponent(query)}',
    ) as Json;
    return (j['items'] as List).map((p) => placeFromJson(p as Json)).toList();
  }

  @override
  Future<QuoteSnapshot> quote(
    Place pickup,
    Place dropoff,
    String service,
  ) async {
    final j = await _client.request(
      '/quotes',
      method: 'POST',
      body: {
        'pickup': placeToJson(pickup),
        'dropoff': placeToJson(dropoff),
        'serviceTypeCode': service,
        'paymentMethodType': 'CASH',
      },
    ) as Json;
    return QuoteSnapshot(
      id: j['quoteId'] as String,
      fare: fareFromJson(j['fare'] as Json),
      distanceMeters: j['estimatedDistanceMeters'] as int,
      durationSeconds: j['estimatedDurationSeconds'] as int,
      expiresAt: deadlineFromJson(j, 'expiresAt'),
      source: j['routeSource'] as String,
    );
  }

  @override
  Future<RideSnapshot> create(QuoteSnapshot quote) async => rideFromJson(
    await _client.request(
      '/rides',
      method: 'POST',
      body: {'quoteId': quote.id},
      idempotent: true,
    ) as Json,
  );
  @override
  Future<RideSnapshot> command(
    RideSnapshot ride,
    String command, {
    String? pin,
    String? reason,
    PositionEvidence? position,
    String? completionType,
  }) async => rideFromJson(
    await _client.request(
      '/rides/${ride.id}/$command',
      method: 'POST',
      idempotent: true,
      body: {
        'expectedVersion': ride.version,
        'pickupPin': ?pin,
        'reasonCode': ?reason,
        if (position != null) 'location': positionToJson(position),
        'completionType': ?completionType,
      },
    ) as Json,
  );
  @override
  Future<void> cash(PaymentSnapshot payment, int amount, String reason) async {
    await _client.request(
      '/payments/${payment.id}/cash-collections',
      method: 'POST',
      idempotent: true,
      body: {
        'operationId': 'cash-${payment.id}-${payment.paid}-$amount',
        'collectedAmount': amount,
        'currency': 'VND',
        'reasonCode': reason,
      },
    );
  }

  @override
  Future<void> rate(RideSnapshot ride, int stars, String comment) async {
    await _client.request(
      '/rides/${ride.id}/ratings',
      method: 'POST',
      body: {'stars': stars, 'comment': comment},
    );
  }

  @override
  Future<String> share(RideSnapshot ride) async {
    final result = await _client.request(
      '/rides/${ride.id}/share-tokens',
      method: 'POST',
    ) as Json;
    const portal = String.fromEnvironment(
      'PORTAL_BASE_URL',
      defaultValue: 'http://127.0.0.1:5173',
    );
    return '$portal/share/${result['token']}';
  }

  @override
  Future<String> sos(RideSnapshot ride) async {
    final result = await _client.request(
      '/rides/${ride.id}/safety-incidents',
      method: 'POST',
    ) as Json;
    return result['message'] as String;
  }

  @override
  Future<void> support(String message, {String? rideId}) async {
    await _client.request(
      '/support/tickets',
      method: 'POST',
      body: {
        'subject': 'Yêu cầu hỗ trợ hành trình',
        'category': 'RIDE',
        'message': message,
        'rideId': rideId,
      },
    );
  }

  @override
  Stream<void> updates() {
    late StreamController<void> stream;
    HubConnection? hub;
    Timer? polling;
    var disposed = false;
    stream = StreamController<void>(
      onListen: () async {
        polling = Timer.periodic(const Duration(seconds: 5), (_) {
          if (!disposed) stream.add(null);
        });
        hub = HubConnectionBuilder()
            .withUrl(
              '${_client.baseUrl}/hubs/rides',
              options: HttpConnectionOptions(
                accessTokenFactory: _client.accessToken,
              ),
            )
            .withAutomaticReconnect()
            .build();
        for (final event in [
          'ride.status.changed',
          'driver.offer.created',
          'payment.status.changed',
          'ride.driver.location.updated',
          'driver.offer.closed',
        ]) {
          hub!.on(event, (_) {
            if (!disposed) stream.add(null);
          });
        }
        hub!.onreconnected(({connectionId}) {
          if (!disposed) stream.add(null);
        });
        try {
          await hub!.start();
        } catch (_) {
          /* REST polling keeps snapshots recoverable. */
        }
        if (disposed) await hub?.stop();
      },
      onCancel: () async {
        disposed = true;
        polling?.cancel();
        await hub?.stop();
      },
    );
    return stream.stream;
  }
}

class ApiDriverRepository implements DriverRepository {
  final ApiClient _client;
  ApiDriverRepository(this._client);
  @override
  Future<void> recordContactAttempt(
    RideSnapshot ride,
    String channel,
    String note,
  ) async {
    await _client.request(
      '/rides/${ride.id}/contact-attempts',
      method: 'POST',
      idempotent: true,
      body: {'channel': channel, 'note': note},
    );
  }

  @override
  Future<Availability> availability() async {
    final j = await _client.request('/drivers/me/availability') as Json;
    return Availability(
      online: j['online'] as bool,
      busy: j['busy'] as bool,
      offlineAfterRide: j['offlineAfterRide'] as bool,
      deviceActive: j['deviceActive'] as bool,
      version: j['version'] as int,
      reviewStatus: j['reviewStatus'] as String,
    );
  }

  @override
  Future<void> setOnline(Availability current, bool online) async {
    await _client.request(
      '/drivers/me/availability',
      method: 'POST',
      body: {'expectedVersion': current.version, 'online': online},
    );
  }

  @override
  Future<void> heartbeat() async {
    await _client.request('/drivers/me/heartbeat', method: 'POST');
  }

  @override
  Future<void> location(PositionEvidence position) async {
    await _client.request(
      '/drivers/me/location-batches',
      method: 'POST',
      body: {
        'samples': [positionToJson(position)],
      },
    );
  }

  @override
  Future<DriverOffer?> currentOffer() async {
    final envelope =
        await _client.request('/drivers/me/offers/current') as Json;
    final j = envelope['offer'] as Json?;
    if (j != null) j['serverTime'] = envelope['serverTime'];
    return j == null
        ? null
        : DriverOffer(
            id: j['offerId'] as String,
            rideId: j['rideId'] as String,
            service: j['serviceTypeCode'] as String,
            version: j['version'] as int,
            entitlement: j['driverEntitlement'] as int,
            payable: j['customerPayable'] as int,
            expiresAt: deadlineFromJson(j, 'expiresAt'),
            pickup: placeFromJson(j['pickup'] as Json),
          );
  }

  @override
  Future<RideSnapshot> accept(DriverOffer offer) async => rideFromJson(
    await _client.request(
      '/driver-offers/${offer.id}/accept',
      method: 'POST',
      idempotent: true,
      body: {'expectedVersion': offer.version},
    ) as Json,
  );
  @override
  Future<void> reject(DriverOffer offer) async {
    await _client.request('/driver-offers/${offer.id}/reject', method: 'POST');
  }

  @override
  Future<Earnings> earnings() async {
    final j = await _client.request('/drivers/me/earnings') as Json;
    final b = j['balance'] as Json;
    return Earnings(
      completedRides: j['completedRides'] as int,
      entitlement: j['entitlement'] as int,
      commission: j['commission'] as int,
      available: b['available'] as int,
      pending: b['pending'] as int,
      held: b['held'] as int,
      debt: b['debt'] as int,
    );
  }
}

class DeviceLocationProvider implements LocationProvider {
  @override
  Future<PositionEvidence> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const Failure('GPS_DISABLED', 'Vui lòng bật định vị thiết bị.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const Failure(
        'GPS_DENIED',
        'Chưa có quyền định vị. Bạn vẫn có thể nhập điểm đón thủ công.',
      );
    }
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return PositionEvidence(
      latitude: p.latitude,
      longitude: p.longitude,
      accuracy: p.accuracy,
      recordedAt: p.timestamp,
      sequence: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
