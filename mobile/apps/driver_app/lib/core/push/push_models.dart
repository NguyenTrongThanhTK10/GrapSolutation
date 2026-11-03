class PushMessage {
  final String id, userId, kind, entityId;
  const PushMessage(this.id, this.userId, this.kind, this.entityId);
  static PushMessage? parse(Map<String, dynamic> data) {
    final id = data['notificationId'],
        user = data['userId'],
        kind = data['entityType'],
        entity = data['entityId'];
    if (id is! String ||
        id.isEmpty ||
        user is! String ||
        user.isEmpty ||
        kind is! String ||
        !const [
          'ride',
          'offer',
          'ticket',
          'application',
          'test',
        ].contains(kind) ||
        entity is! String)
      return null;
    return PushMessage(id, user, kind, entity);
  }
}

class PushEvent {
  final PushMessage message;
  final bool opened;
  const PushEvent(this.message, {this.opened = false});
}

class PushStatus {
  final bool available, busy, registered, deliveryEnabled;
  final String permission;
  final String? error;
  const PushStatus({
    required this.available,
    this.busy = false,
    this.registered = false,
    this.deliveryEnabled = false,
    this.permission = 'unknown',
    this.error,
  });
}

abstract interface class PushGateway {
  bool get available;
  String get platform;
  Stream<String> get tokenChanges;
  Stream<PushEvent> get messages;
  Future<PushMessage?> initialMessage();
  Future<String> permission({bool request = false});
  Future<String?> token();
  Future<void> deleteToken();
  Future<void> autoInit(bool enabled);
  Future<void> openSettings();
}

class DisabledPushGateway implements PushGateway {
  const DisabledPushGateway();
  @override
  bool get available => false;
  @override
  String get platform => 'android';
  @override
  Stream<String> get tokenChanges => const Stream.empty();
  @override
  Stream<PushEvent> get messages => const Stream.empty();
  @override
  Future<PushMessage?> initialMessage() async => null;
  @override
  Future<String> permission({bool request = false}) async => 'unavailable';
  @override
  Future<String?> token() async => null;
  @override
  Future<void> deleteToken() async {}
  @override
  Future<void> autoInit(bool enabled) async {}
  @override
  Future<void> openSettings() async {}
}
