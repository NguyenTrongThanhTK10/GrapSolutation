class Failure implements Exception {
  final String code, message;
  const Failure(this.code, this.message);
  @override
  String toString() => message;
}

class Profile {
  final GrapUser user;
  final String phone;
  final String? email;
  final int version;
  const Profile({
    required this.user,
    required this.phone,
    this.email,
    required this.version,
  });
}

class DriverApplication {
  final String id, status, service, plate, vehicle, color;
  final String? reason;
  final int version;
  const DriverApplication({
    required this.id,
    required this.status,
    required this.service,
    required this.plate,
    required this.vehicle,
    required this.color,
    this.reason,
    required this.version,
  });
  bool get editable => status == 'DRAFT' || status == 'REJECTED';
}

class DriverDocument {
  final String id, type, status;
  final String? reason;
  final int version;
  final DateTime expiresAt;
  const DriverDocument({
    required this.id,
    required this.type,
    required this.status,
    required this.version,
    required this.expiresAt,
    this.reason,
  });
}

class DocumentBundle {
  final List<String> requiredTypes;
  final List<DriverDocument> documents;
  const DocumentBundle(this.requiredTypes, this.documents);
  DriverDocument? latest(String type) {
    final matches = documents.where((d) => d.type == type).toList()
      ..sort((a, b) => b.version.compareTo(a.version));
    return matches.firstOrNull;
  }

  bool get ready => requiredTypes.every((type) {
    final d = latest(type);
    return d != null &&
        d.status != 'REJECTED' &&
        d.expiresAt.isAfter(DateTime.now().toUtc());
  });
}

class SupportTicket {
  final String id, subject, status, category, priority;
  final DateTime createdAt;
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.status,
    required this.category,
    required this.priority,
    required this.createdAt,
  });
}

class SupportMessage {
  final String id, authorId, body;
  final DateTime createdAt;
  const SupportMessage({
    required this.id,
    required this.authorId,
    required this.body,
    required this.createdAt,
  });
}

class TicketDetail {
  final SupportTicket ticket;
  final List<SupportMessage> messages;
  const TicketDetail(this.ticket, this.messages);
}

class AppNotification {
  final String id, title, body;
  final String? entityId;
  final DateTime createdAt;
  final bool read;
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.entityId,
    required this.createdAt,
    required this.read,
  });
}

class RideShare {
  final String id, url;
  final DateTime expiresAt;
  const RideShare(this.id, this.url, this.expiresAt);
}

class PendingOperation {
  final String id, path;
  final DateTime createdAt;
  const PendingOperation(this.id, this.path, this.createdAt);
}

class GrapUser {
  final String id, name, role;
  const GrapUser({required this.id, required this.name, required this.role});
}

class OtpChallengeSnapshot {
  final String id;
  final DateTime expiresAt, resendAt;
  const OtpChallengeSnapshot({
    required this.id,
    required this.expiresAt,
    required this.resendAt,
  });
}

class Place {
  final String id, address;
  final double latitude, longitude;
  const Place({
    required this.id,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class Fare {
  final int payable, gross, commission;
  final int base, distance, duration, serviceFee, discount, extras, tax;
  const Fare({
    required this.payable,
    required this.gross,
    required this.commission,
    this.base = 0,
    this.distance = 0,
    this.duration = 0,
    this.serviceFee = 0,
    this.discount = 0,
    this.extras = 0,
    this.tax = 0,
  });
}

class QuoteSnapshot {
  final String id, source;
  final Fare fare;
  final int distanceMeters, durationSeconds;
  final DateTime expiresAt;
  const QuoteSnapshot({
    required this.id,
    required this.fare,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.expiresAt,
    required this.source,
  });
  bool get expired => !expiresAt.isAfter(DateTime.now().toUtc());
}

class DriverInfo {
  final String name, vehicle, plate, color;
  final Place? location;
  final DateTime? locationAt;
  const DriverInfo({
    required this.name,
    required this.vehicle,
    required this.plate,
    required this.color,
    this.location,
    this.locationAt,
  });
}

class PaymentSnapshot {
  final String id, status;
  final int payable, paid;
  const PaymentSnapshot({
    required this.id,
    required this.status,
    required this.payable,
    required this.paid,
  });
  int get remaining => payable - paid;
}

class RideSnapshot {
  final String id, code, status, service;
  final int version;
  final Place pickup, dropoff;
  final Fare fare;
  final DateTime createdAt;
  final DateTime? arrivedAt;
  final String? pickupPin;
  final DriverInfo? driver;
  final PaymentSnapshot? payment;
  const RideSnapshot({
    required this.id,
    required this.code,
    required this.status,
    required this.service,
    required this.version,
    required this.pickup,
    required this.dropoff,
    required this.fare,
    required this.createdAt,
    this.arrivedAt,
    this.pickupPin,
    this.driver,
    this.payment,
  });
  bool get active => const [
    'SEARCHING',
    'ASSIGNED',
    'DRIVER_ARRIVED',
    'IN_PROGRESS',
  ].contains(status);
}

class Availability {
  final bool online, busy, offlineAfterRide, deviceActive;
  final int version;
  final String reviewStatus;
  const Availability({
    required this.online,
    required this.busy,
    required this.offlineAfterRide,
    required this.deviceActive,
    required this.version,
    required this.reviewStatus,
  });
}

class DriverOffer {
  final String id, rideId, service;
  final int version, entitlement, payable;
  final DateTime expiresAt;
  final Place pickup;
  const DriverOffer({
    required this.id,
    required this.rideId,
    required this.service,
    required this.version,
    required this.entitlement,
    required this.payable,
    required this.expiresAt,
    required this.pickup,
  });
}

class Earnings {
  final int completedRides,
      entitlement,
      commission,
      available,
      pending,
      held,
      debt;
  const Earnings({
    required this.completedRides,
    required this.entitlement,
    required this.commission,
    required this.available,
    required this.pending,
    required this.held,
    required this.debt,
  });
}

class PositionEvidence {
  final double latitude, longitude, accuracy;
  final DateTime recordedAt;
  final int sequence;
  const PositionEvidence({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.recordedAt,
    required this.sequence,
  });
}
