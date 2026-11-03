import '../domain/models.dart';
import '../domain/repositories.dart';

class CustomerUseCases {
  final RideRepository repository;
  const CustomerUseCases(this.repository);
  Future<QuoteSnapshot> quote(Place pickup, Place dropoff, String service) {
    if (pickup.id == dropoff.id ||
        pickup.latitude == dropoff.latitude &&
            pickup.longitude == dropoff.longitude) {
      throw const Failure(
        'INVALID_COORDINATES',
        'Điểm đón và điểm đến phải khác nhau.',
      );
    }
    return repository.quote(pickup, dropoff, service);
  }

  Future<RideSnapshot> book(QuoteSnapshot quote) {
    if (quote.expired) {
      throw const Failure(
        'QUOTE_EXPIRED',
        'Báo giá đã hết hạn. Vui lòng xem giá mới.',
      );
    }
    return repository.create(quote);
  }

  Future<RideSnapshot> cancel(RideSnapshot ride, String reason) {
    if (!const [
      'SEARCHING',
      'ASSIGNED',
      'DRIVER_ARRIVED',
    ].contains(ride.status)) {
      throw const Failure(
        'INVALID_RIDE_STATE',
        'Không thể hủy chuyến đã bắt đầu.',
      );
    }
    return repository.command(ride, 'cancel', reason: reason);
  }
}

class DriverUseCases {
  final RideRepository rides;
  final DriverRepository drivers;
  final LocationProvider location;
  const DriverUseCases(this.rides, this.drivers, this.location);
  Future<void> publishPosition({PositionEvidence? developmentPosition}) async {
    await drivers.location(developmentPosition ?? await location.current());
    await drivers.heartbeat();
  }

  Future<RideSnapshot> arrive(
    RideSnapshot ride, {
    PositionEvidence? developmentPosition,
  }) async => rides.command(
    ride,
    'arrive',
    position: developmentPosition ?? await location.current(),
  );
  Future<RideSnapshot> start(RideSnapshot ride, String pin) {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw const Failure(
        'PIN_INVALID',
        'Nhập đúng 4 chữ số từ ứng dụng khách hàng.',
      );
    }
    return rides.command(ride, 'start', pin: pin);
  }

  Future<RideSnapshot> complete(
    RideSnapshot ride, {
    PositionEvidence? developmentPosition,
  }) async => rides.command(
    ride,
    'complete',
    position: developmentPosition ?? await location.current(),
  );
}
