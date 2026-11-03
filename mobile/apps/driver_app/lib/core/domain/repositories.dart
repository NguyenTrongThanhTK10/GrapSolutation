import 'models.dart';

abstract interface class AuthRepository {
  Future<GrapUser?> restore();
  Future<List<GrapUser>> developmentAccounts(String role);
  Future<GrapUser> developmentLogin(String userId);
  Future<OtpChallengeSnapshot> requestOtp(String phone, String appType);
  Future<GrapUser> verifyOtp(String challengeId, String code);
  Future<void> logout();
  Future<bool> get demoMaps;
}

abstract interface class RideRepository {
  Future<RideSnapshot?> active();
  Future<RideSnapshot> detail(String id);
  Future<List<RideSnapshot>> history();
  Future<List<Place>> places(String query);
  Future<QuoteSnapshot> quote(Place pickup, Place dropoff, String service);
  Future<RideSnapshot> create(QuoteSnapshot quote);
  Future<RideSnapshot> command(
    RideSnapshot ride,
    String command, {
    String? pin,
    String? reason,
    PositionEvidence? position,
    String? completionType,
  });
  Future<void> cash(PaymentSnapshot payment, int amount, String reason);
  Future<void> rate(RideSnapshot ride, int stars, String comment);
  Future<String> share(RideSnapshot ride);
  Future<String> sos(RideSnapshot ride);
  Future<void> support(String message, {String? rideId});
  Stream<void> updates();
}

abstract interface class DriverRepository {
  Future<Availability> availability();
  Future<void> setOnline(Availability current, bool online);
  Future<void> heartbeat();
  Future<void> location(PositionEvidence position);
  Future<DriverOffer?> currentOffer();
  Future<RideSnapshot> accept(DriverOffer offer);
  Future<void> reject(DriverOffer offer);
  Future<Earnings> earnings();
  Future<void> recordContactAttempt(
    RideSnapshot ride,
    String channel,
    String note,
  );
}

abstract interface class LocationProvider {
  Future<PositionEvidence> current();
}

abstract interface class AccountRepository {
  Future<Profile> profile();
  Future<Profile> updateProfile(Profile current, String name, String? email);
  Future<List<SupportTicket>> tickets();
  Future<TicketDetail> ticket(String id);
  Future<void> createTicket(
    String subject,
    String category,
    String message, {
    String? rideId,
  });
  Future<void> reply(String ticketId, String message);
  Future<List<AppNotification>> notifications();
  Future<void> markRead(String id);
  Future<RideShare> createShare(RideSnapshot ride);
  Future<void> revokeShare(RideSnapshot ride, String shareId);
}

abstract interface class OnboardingRepository {
  Future<DriverApplication> application();
  Future<DriverApplication> save(
    DriverApplication current,
    String service,
    String vehicle,
    String plate,
    String color,
  );
  Future<DocumentBundle> documents();
  Future<void> uploadDocument(
    String type,
    List<int> bytes,
    String contentType,
    DateTime expiresAt,
  );
  Future<void> submit(int expectedVersion);
  Future<bool> uploadEnabled();
}

abstract interface class RecoveryRepository {
  Future<List<PendingOperation>> pending();
  Future<void> retry(String id);
}
