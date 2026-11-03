import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../network/api_client.dart';
import '../domain/models.dart';
import 'push_models.dart';

class PushCoordinator {
  final ApiClient client;
  final FlutterSecureStorage storage;
  final PushGateway gateway;
  final String appType;
  final _events = StreamController<PushEvent>.broadcast();
  final _statuses = StreamController<PushStatus>.broadcast();
  late final StreamSubscription<String> _tokens;
  late final StreamSubscription<PushEvent> _messages;
  final _seen = <String>{};
  String? _userId, _latestToken, _registeredToken;
  PushMessage? _pendingOpen;
  int _generation = 0, _scope = -1;
  bool _disposed = false, _allowRegistration = false;
  Future<String>? _installation;
  Future<void> _registrations = Future.value();
  late PushStatus status = PushStatus(available: gateway.available);
  Stream<PushEvent> get events => _events.stream;
  Stream<PushStatus> get statuses => _statuses.stream;
  PushCoordinator(this.client, this.storage, this.gateway, this.appType) {
    _tokens = gateway.tokenChanges.listen((token) {
      if (_userId != null && _allowRegistration) {
        _latestToken = token;
        unawaited(_register(token, _generation, _scope));
      }
    });
    _messages = gateway.messages.listen(_receive);
    unawaited(_initial());
  }
  bool _current(int generation, int scope) =>
      !_disposed &&
      generation == _generation &&
      scope == client.sessionScope &&
      _userId != null;
  void _status(PushStatus value) {
    if (!_disposed) {
      status = value;
      _statuses.add(value);
    }
  }

  Future<void> _initial() async {
    try {
      final message = await gateway.initialMessage();
      if (message != null) _receive(PushEvent(message, opened: true));
    } catch (_) {}
  }

  void _receive(PushEvent event) {
    if (_disposed) return;
    if (_userId == null) {
      if (event.opened) _pendingOpen = event.message;
      return;
    }
    if (event.message.userId != _userId) return;
    final key = '${event.opened}:${event.message.id}';
    if (!_seen.add(key)) return;
    if (_seen.length > 100) _seen.remove(_seen.first);
    _events.add(event);
  }

  Future<String> _installationId() => _installation ??= (() async {
    final saved = await storage.read(key: 'grap.push.installation');
    if (saved != null && Uuid.isValidUUID(fromString: saved)) return saved;
    final id = const Uuid().v4();
    await storage.write(key: 'grap.push.installation', value: id);
    return id;
  })();
  Future<void> bind(String? userId) async {
    if (_disposed || (_userId == userId && _scope == client.sessionScope))
      return;
    _allowRegistration = false;
    _generation++;
    _scope = client.sessionScope;
    _userId = userId;
    _latestToken = null;
    _registeredToken = null;
    _seen.clear();
    _status(PushStatus(available: gateway.available));
    if (userId == null) return;
    final pending = _pendingOpen;
    _pendingOpen = null;
    if (pending != null) _receive(PushEvent(pending, opened: true));
    await synchronize();
  }

  Future<void> synchronize({bool requestPermission = false}) async {
    final generation = _generation, scope = _scope;
    if (!_current(generation, scope) || !gateway.available) return;
    _status(
      PushStatus(
        available: true,
        busy: true,
        registered: status.registered,
        deliveryEnabled: status.deliveryEnabled,
        permission: status.permission,
      ),
    );
    try {
      final enabled = await storage.read(key: 'grap.push.enabled') != 'false';
      if (!enabled && !requestPermission) {
        if (_current(generation, scope))
          _status(const PushStatus(available: true, permission: 'disabled'));
        return;
      }
      final permission = await gateway.permission(request: requestPermission);
      if (!_current(generation, scope)) return;
      if (permission != 'authorized') {
        await _unregister(generation, scope);
        if (_current(generation, scope))
          _status(PushStatus(available: true, permission: permission));
        return;
      }
      if (requestPermission)
        await storage.write(key: 'grap.push.enabled', value: 'true');
      if (!_current(generation, scope)) return;
      _allowRegistration = true;
      await gateway.autoInit(true);
      final token = await gateway.token();
      if (!_current(generation, scope)) return;
      if (token == null || token.isEmpty)
        throw const Failure(
          'PUSH_TOKEN_UNAVAILABLE',
          'Chưa lấy được token thông báo. Hãy thử lại khi có mạng.',
        );
      _latestToken = token;
      await _register(token, generation, scope);
    } catch (e) {
      if (_current(generation, scope))
        _status(
          PushStatus(
            available: true,
            permission: status.permission,
            error: e is Failure
                ? e.message
                : 'Chưa đồng bộ được thông báo. Vui lòng thử lại.',
          ),
        );
    }
  }

  Future<void> _register(String token, int generation, int scope) {
    final next = _registrations.catchError((Object _) {}).then((_) async {
      if (!_current(generation, scope) ||
          !_allowRegistration ||
          token != _latestToken)
        return;
      try {
        final id = await _installationId();
        if (!_current(generation, scope) ||
            !_allowRegistration ||
            token != _latestToken)
          return;
        final result = await client.request(
          '/me/push-devices/$id',
          method: 'PUT',
          body: {
            'token': token,
            'platform': gateway.platform,
            'appType': appType,
          },
        ) as Map<String, dynamic>;
        if (!_current(generation, scope) ||
            !_allowRegistration ||
            token != _latestToken)
          return;
        _registeredToken = token;
        _status(
          PushStatus(
            available: true,
            registered: result['registered'] == true,
            deliveryEnabled: result['deliveryEnabled'] == true,
            permission: 'authorized',
          ),
        );
      } catch (e) {
        if (_current(generation, scope))
          _status(
            PushStatus(
              available: true,
              permission: 'authorized',
              error: e is Failure
                  ? e.message
                  : 'Chưa đăng ký được thiết bị. Hãy thử lại.',
            ),
          );
      }
    });
    _registrations = next;
    return next;
  }

  Future<void> _unregister(int generation, int scope) {
    final next = _registrations.catchError((Object _) {}).then((_) async {
      final id = await _installationId();
      if (!_current(generation, scope)) return;
      await client.request('/me/push-devices/$id', method: 'DELETE');
      if (_current(generation, scope)) _registeredToken = null;
    });
    _registrations = next;
    return next;
  }

  Future<void> disable() async {
    _allowRegistration = false;
    final generation = ++_generation, scope = _scope;
    if (!_current(generation, scope)) return;
    try {
      await storage.write(key: 'grap.push.enabled', value: 'false');
      await _unregister(generation, scope);
      if (!_current(generation, scope)) return;
      await gateway.autoInit(false);
      await gateway.deleteToken();
      _latestToken = null;
      _registeredToken = null;
      if (_current(generation, scope))
        _status(const PushStatus(available: true, permission: 'disabled'));
    } catch (_) {
      if (_current(generation, scope))
        _status(
          const PushStatus(
            available: true,
            error: 'Chưa tắt thông báo trên máy chủ. Hãy thử lại khi có mạng.',
          ),
        );
    }
  }

  Future<void> disconnect() async {
    _allowRegistration = false;
    final generation = _generation, scope = _scope;
    try {
      if (gateway.available && _userId != null)
        await _unregister(generation, scope);
    } catch (_) {}
    if (_disposed || generation != _generation) return;
    _generation++;
    _userId = null;
    _latestToken = null;
    _registeredToken = null;
    _pendingOpen = null;
    _seen.clear();
    try {
      if (gateway.available) await gateway.deleteToken();
    } catch (_) {}
    _status(PushStatus(available: gateway.available));
  }

  Future<void> sendTest() async {
    if (_registeredToken == null)
      throw const Failure(
        'PUSH_DEVICE_REQUIRED',
        'Vui lòng bật thông báo trước khi gửi thử.',
      );
    await client.request(
      '/me/push-test',
      method: 'POST',
      idempotent: true,
      body: const {},
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    _generation++;
    await _tokens.cancel();
    await _messages.cancel();
    await _events.close();
    await _statuses.close();
  }
}
