import 'models.dart';

class RidePage {
  final List<RideSnapshot> items;
  final String? nextCursor;
  const RidePage(this.items, this.nextCursor);
}

class RideTimelineEntry {
  final String type;
  final DateTime at;
  const RideTimelineEntry(this.type, this.at);
}

class RideReceipt {
  final RideSnapshot ride;
  final List<RideTimelineEntry> events;
  final int? stars;
  final String comment;
  final bool canReview;
  final DateTime? editableUntil;
  const RideReceipt(
    this.ride,
    this.events,
    this.stars,
    this.comment,
    this.canReview,
    this.editableUntil,
  );
}

class SavedAddress {
  final String id, label, note;
  final Place point;
  final int version;
  const SavedAddress(this.id, this.label, this.point, this.note, this.version);
}

class TrustedPerson {
  final String id, name, phone;
  final int version;
  const TrustedPerson(this.id, this.name, this.phone, this.version);
}

class TrustedContacts {
  final List<TrustedPerson> items;
  final bool offline;
  const TrustedContacts(this.items, {this.offline = false});
}

class DeletionStatus {
  final String id, status, reason, ticketId;
  final String? reviewNote;
  final int version;
  final List<String> blockers;
  const DeletionStatus(
    this.id,
    this.status,
    this.reason,
    this.ticketId,
    this.reviewNote,
    this.version,
    this.blockers,
  );
  bool get open => const [
    'REQUESTED',
    'BLOCKED_OBLIGATIONS',
    'IN_REVIEW',
    'NEEDS_INFORMATION',
  ].contains(status);
}

abstract interface class JourneyRepository {
  Future<RidePage> history({
    String? status,
    DateTime? from,
    DateTime? to,
    String? cursor,
  });
  Future<RideReceipt> receipt(String rideId);
  Future<List<SavedAddress>> addresses();
  Future<void> saveAddress(
    String label,
    Place point,
    String note, {
    SavedAddress? current,
  });
  Future<void> deleteAddress(SavedAddress address);
  Future<TrustedContacts> contacts();
  Future<void> saveContact(
    String name,
    String phone,
    bool consent, {
    TrustedPerson? current,
  });
  Future<void> deleteContact(TrustedPerson contact);
  Future<List<DeletionStatus>> deletionRequests();
  Future<void> requestDeletion(String reason);
  Future<void> changeDeletion(DeletionStatus request, String action);
}
