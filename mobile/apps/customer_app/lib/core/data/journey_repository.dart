import '../domain/journey.dart';
import '../domain/models.dart';
import '../network/api_client.dart';
import 'mappers.dart';

class ApiJourneyRepository implements JourneyRepository {
  final ApiClient client;
  int _contactRevision = 0;
  ApiJourneyRepository(this.client);
  @override
  Future<RidePage> history({
    String? status,
    DateTime? from,
    DateTime? to,
    String? cursor,
  }) async {
    final query = Uri(
      queryParameters: {
        'pageSize': '20',
        'status': ?status,
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
        'cursor': ?cursor,
      },
    ).query;
    final j = await client.request('/rides?$query') as Json;
    return RidePage(
      (j['items'] as List).map((e) => rideFromJson(e as Json)).toList(),
      j['nextCursor'] as String?,
    );
  }

  @override
  Future<RideReceipt> receipt(String rideId) async {
    final results = await Future.wait([
      client.request('/rides/$rideId'),
      client.request('/rides/$rideId/events'),
      client.request('/rides/$rideId/ratings/me'),
    ]);
    final review = results[2] as Json,
        rating = (results[2] as Json)['rating'] as Json?;
    return RideReceipt(
      rideFromJson(results[0] as Json),
      ((results[1] as Json)['items'] as List)
          .map(
            (e) => RideTimelineEntry(
              e['eventType'] as String,
              DateTime.parse(e['createdAt'] as String),
            ),
          )
          .toList(),
      rating?['stars'] as int?,
      rating?['comment'] as String? ?? '',
      review['canEdit'] == true,
      review['editableUntil'] == null
          ? null
          : DateTime.parse(review['editableUntil'] as String),
    );
  }

  @override
  Future<List<SavedAddress>> addresses() async =>
      ((await client.request('/customers/me/saved-places') as Json)['items']
              as List)
          .map(
            (e) => SavedAddress(
              e['id'] as String,
              e['label'] as String,
              placeFromJson({...e as Json, 'placeId': 'saved-${e['id']}'}),
              e['note'] as String,
              e['version'] as int,
            ),
          )
          .toList();
  @override
  Future<void> saveAddress(
    String label,
    Place point,
    String note, {
    SavedAddress? current,
  }) async {
    await client.request(
      '/customers/me/saved-places${current == null ? '' : '/${current.id}'}',
      method: current == null ? 'POST' : 'PATCH',
      idempotent: current == null,
      body: {
        'label': label.trim(),
        'point': placeToJson(point),
        'note': note.trim(),
        if (current != null) 'expectedVersion': current.version,
      },
    );
  }

  @override
  Future<void> deleteAddress(SavedAddress address) async {
    await client.request(
      '/customers/me/saved-places/${address.id}?expectedVersion=${address.version}',
      method: 'DELETE',
    );
  }

  List<TrustedPerson> _contacts(Json j) => (j['items'] as List)
      .map(
        (e) => TrustedPerson(
          e['id'] as String,
          e['name'] as String,
          e['phone'] as String,
          e['version'] as int,
        ),
      )
      .toList();
  @override
  Future<TrustedContacts> contacts() async {
    // Capture the session before IO so a stale response cannot enter another account's cache.
    final scope = client.sessionScope;
    final revision = _contactRevision;
    try {
      final j = await client.request('/me/trusted-contacts') as Json;
      if (revision != _contactRevision) return await contacts();
      await client.writeContactCache(scope, j);
      return TrustedContacts(_contacts(j));
    } on Failure catch (e) {
      if (e.code != 'NETWORK_ERROR' &&
          !RegExp(r'^HTTP_5\d\d$').hasMatch(e.code)) {
        rethrow;
      }
      final cached = await client.readContactCache(scope);
      if (cached == null) rethrow;
      return TrustedContacts(_contacts(cached), offline: true);
    }
  }

  @override
  Future<void> saveContact(
    String name,
    String phone,
    bool consent, {
    TrustedPerson? current,
  }) async {
    final scope = client.sessionScope;
    await client.request(
      '/me/trusted-contacts${current == null ? '' : '/${current.id}'}',
      method: current == null ? 'POST' : 'PATCH',
      idempotent: current == null,
      body: {
        'name': name.trim(),
        'phone': phone.trim(),
        'consentAccepted': consent,
        if (current != null) 'expectedVersion': current.version,
      },
    );
    _contactRevision++;
    await client.writeContactCache(scope, null);
  }

  @override
  Future<void> deleteContact(TrustedPerson contact) async {
    final scope = client.sessionScope;
    await client.request(
      '/me/trusted-contacts/${contact.id}?expectedVersion=${contact.version}',
      method: 'DELETE',
    );
    _contactRevision++;
    await client.writeContactCache(scope, null);
  }

  @override
  Future<List<DeletionStatus>> deletionRequests() async =>
      ((await client.request('/me/account-deletion-requests') as Json)['items']
              as List)
          .map(
            (e) => DeletionStatus(
              e['id'] as String,
              e['status'] as String,
              e['reason'] as String,
              e['ticketId'] as String,
              e['reviewNote'] as String?,
              e['version'] as int,
              (e['blockers'] as List).cast<String>(),
            ),
          )
          .toList();
  @override
  Future<void> requestDeletion(String reason) async {
    await client.request(
      '/me/account-deletion-requests',
      method: 'POST',
      idempotent: true,
      body: {'reason': reason.trim()},
    );
  }

  @override
  Future<void> changeDeletion(DeletionStatus request, String action) async {
    if (!const ['recheck', 'cancel'].contains(action)) {
      throw const Failure('VALIDATION_ERROR', 'Thao tác không hợp lệ.');
    }
    await client.request(
      '/me/account-deletion-requests/${request.id}/$action',
      method: 'POST',
      idempotent: true,
      body: {'expectedVersion': request.version},
    );
  }
}
