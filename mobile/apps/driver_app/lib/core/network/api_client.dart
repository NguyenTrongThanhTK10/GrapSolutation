import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import 'dio_config.dart';

/// A session-scoped transport. Only completion and cash commands are persisted.
/// Retrying those commands reuses the original body, including GPS and version.
class ApiClient {
  final String baseUrl;
  final FlutterSecureStorage storage;
  late final Dio dio;
  Map<String, dynamic>? _session;
  int _epoch = 0;
  Future<void>? _refreshFlight;
  int? _refreshEpoch;
  Future<void> _writes = Future.value();
  final _volatile = <String, String>{};
  final _journal = <String, Map<String, dynamic>>{};
  final _sessionEnded = StreamController<void>.broadcast();
  Stream<void> get sessionEnded => _sessionEnded.stream;
  ApiClient(this.baseUrl, this.storage, {Dio? transport}) {
    dio = transport ?? Dio();
    dio.options = apiOptions(baseUrl);
  }
  String? get _actor => _session?['user']?['id'] as String?;
  int get sessionScope => _epoch;
  Future<Map<String, dynamic>?> readContactCache(int scope) async {
    _check(scope);
    if (_actor == null) return null;
    final raw = await storage.read(key: 'grap.contacts');
    _check(scope);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final date = decoded['updatedAt'];
      final at = date is String ? DateTime.tryParse(date) : null;
      final data = decoded['data'];
      if (decoded['actorId'] != _actor ||
          at == null ||
          !at.isAfter(
            DateTime.now().toUtc().subtract(const Duration(days: 30)),
          ) ||
          data is! Map<String, dynamic> ||
          data['items'] is! List) {
        return null;
      }
      for (final item in data['items'] as List) {
        if (item is! Map ||
            item['id'] is! String ||
            item['name'] is! String ||
            item['phone'] is! String ||
            item['version'] is! int) {
          return null;
        }
      }
      return data;
    } on FormatException {
      return null;
    }
  }

  Future<void> writeContactCache(int scope, Map<String, dynamic>? data) async {
    _check(scope);
    final encoded = data == null
        ? null
        : jsonEncode({
            'actorId': _actor,
            'data': data,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          });
    final next = _writes.catchError((Object _) {}).then((_) async {
      _check(scope);
      if (encoded == null) {
        await storage.delete(key: 'grap.contacts');
      } else {
        await storage.write(key: 'grap.contacts', value: encoded);
      }
    });
    _writes = next;
    await next;
    _check(scope);
  }

  void _check(int epoch) {
    if (epoch != _epoch) {
      throw const Failure(
        'SESSION_CHANGED',
        'Tài khoản đã thay đổi. Thao tác cũ đã dừng.',
      );
    }
  }

  Future<void> _persist() {
    final actor = _actor;
    final encoded = jsonEncode({'actorId': actor, 'entries': _journal});
    final next = _writes
        .catchError((Object _) {})
        .then((_) => storage.write(key: 'grap.pending', value: encoded));
    _writes = next;
    return next;
  }

  Future<void> _persistSession(int epoch) {
    final encoded = _session == null ? null : jsonEncode(_session);
    final next = _writes.catchError((Object _) {}).then((_) async {
      if (epoch != _epoch) return;
      if (encoded == null) {
        await storage.delete(key: 'grap.session');
      } else {
        await storage.write(key: 'grap.session', value: encoded);
      }
    });
    _writes = next;
    return next;
  }

  Map<String, dynamic>? _validSession(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final user = value['user'], expires = value['expiresAt'];
    if (user is! Map ||
        user['id'] is! String ||
        (user['id'] as String).isEmpty ||
        user['name'] is! String ||
        user['role'] is! String ||
        expires is! String ||
        DateTime.tryParse(expires) == null) {
      return null;
    }
    for (final key in ['accessToken', 'refreshToken']) {
      if (value[key] is! String || (value[key] as String).isEmpty) return null;
    }
    return value;
  }

  Future<void> _loadJournal(int epoch) async {
    final saved = await storage.read(key: 'grap.pending');
    _check(epoch);
    _journal.clear();
    if (saved == null) return;
    try {
      final j = jsonDecode(saved);
      if (j is! Map || j['actorId'] != _actor || j['entries'] is! Map) return;
      for (final entry in (j['entries'] as Map).entries) {
        if (_journal.length == 32) break;
        final value = entry.value;
        if (entry.key is! String || value is! Map<String, dynamic>) continue;
        final path = value['path'],
            key = value['key'],
            date = value['createdAt'];
        final at = date is String ? DateTime.tryParse(date) : null;
        if (path is! String ||
            !_durable(path) ||
            key is! String ||
            key.length < 8 ||
            key.length > 150 ||
            value['body'] is! Map ||
            at == null ||
            !at.isAfter(
              DateTime.now().toUtc().subtract(const Duration(hours: 24)),
            ) ||
            !(entry.key as String).startsWith('$_actor:POST:$path:')) {
          continue;
        }
        _journal[entry.key as String] = value;
      }
    } on FormatException {
      // A damaged retry journal must not discard a valid signed-in session.
    }
    await _persist();
    _check(epoch);
  }

  Future<Map<String, dynamic>?> restore() async {
    final epoch = _epoch;
    final saved = await storage.read(key: 'grap.session');
    _check(epoch);
    if (saved == null) return null;
    try {
      final session = _validSession(jsonDecode(saved));
      if (session == null) {
        await clear();
        return null;
      }
      _session = session;
      await _loadJournal(epoch);
      _check(epoch);
      final profile = await request('/me') as Map<String, dynamic>;
      _check(epoch);
      await cacheProfile(profile);
      _check(epoch);
      return _session;
    } on FormatException {
      _check(epoch);
      await clear();
      return null;
    } on Failure catch (e) {
      if (e.code == 'NETWORK_ERROR') return _session;
      if (e.code == 'SESSION_EXPIRED') return null;
      rethrow;
    }
  }

  Future<void> save(Map<String, dynamic> session) async {
    final valid = _validSession(session);
    if (valid == null) {
      throw const Failure(
        'INVALID_AUTH_RESPONSE',
        'Dữ liệu đăng nhập không hợp lệ. Vui lòng thử lại.',
      );
    }
    final epoch = ++_epoch;
    _session = valid;
    _volatile.clear();
    _journal.clear();
    await _persistSession(epoch);
    _check(epoch);
    await _persist();
    _check(epoch);
    await writeContactCache(epoch, null);
  }

  Future<void> cacheProfile(Map<String, dynamic> profile) async {
    if (_session == null || profile['id'] != _actor) return;
    final epoch = _epoch;
    _session!['user'] = {
      ...(_session!['user'] as Map<String, dynamic>),
      ...profile,
    };
    await _persistSession(epoch);
    _check(epoch);
  }

  Future<void> clear({bool expired = false}) async {
    final epoch = ++_epoch;
    _session = null;
    _volatile.clear();
    _journal.clear();
    await _persistSession(epoch);
    _check(epoch);
    await _persist();
    _check(epoch);
    await writeContactCache(epoch, null);
    if (expired) _sessionEnded.add(null);
  }

  Future<String> accessToken() async {
    if (_session == null) return '';
    if (DateTime.parse(_session!['expiresAt'] as String)
        .isBefore(DateTime.now().toUtc().add(const Duration(seconds: 30)))) {
      await _refresh();
    }
    return _session?['accessToken'] as String? ?? '';
  }

  Future<void> _refresh() {
    final epoch = _epoch;
    if (_refreshFlight != null && _refreshEpoch == epoch) {
      return _refreshFlight!;
    }
    late Future<void> flight;
    flight = _performRefresh(epoch).whenComplete(() {
      if (identical(_refreshFlight, flight)) {
        _refreshFlight = null;
        _refreshEpoch = null;
      }
    });
    _refreshEpoch = epoch;
    _refreshFlight = flight;
    return flight;
  }

  Future<void> _performRefresh(int epoch) async {
    try {
      final result = await dio.post<dynamic>(
        '/auth/token/refresh',
        data: {'refreshToken': _session?['refreshToken']},
      );
      _check(epoch);
      final refreshed = _validSession(result.data);
      if (refreshed == null || (refreshed['user'] as Map)['id'] != _actor) {
        throw const Failure(
          'INVALID_AUTH_RESPONSE',
          'Không nhận được phiên xác thực hợp lệ. Vui lòng thử lại.',
        );
      }
      _session = refreshed;
      await _persistSession(epoch);
      _check(epoch);
    } on DioException catch (e) {
      _check(epoch);
      if (e.response?.statusCode == 401) {
        await clear(expired: true);
        throw const Failure(
          'SESSION_EXPIRED',
          'Phiên đã hết hạn. Vui lòng đăng nhập lại.',
        );
      }
      throw const Failure(
        'NETWORK_ERROR',
        'Không thể làm mới phiên. Vui lòng thử lại khi có mạng.',
      );
    }
  }

  static bool _durable(String path) =>
      RegExp(r'^/rides/[^/]+/complete$|^/payments/[^/]+/cash-collections$')
          .hasMatch(path);
  Future<List<PendingOperation>> pending() async => _journal.entries
      .map(
        (e) => PendingOperation(
          e.key,
          e.value['path'] as String,
          DateTime.parse(e.value['createdAt'] as String),
        ),
      )
      .toList();
  Future<void> retry(String id) async {
    final record = _journal[id];
    if (record == null) {
      throw const Failure(
        'COMMAND_NOT_FOUND',
        'Thao tác này đã được xác nhận hoặc không còn thuộc tài khoản.',
      );
    }
    await request(
      record['path'] as String,
      method: 'POST',
      body: record['body'],
      idempotent: true,
    );
  }

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Object? body,
    bool idempotent = false,
    List<int>? bytes,
    String? contentType,
  }) async {
    final epoch = _epoch;
    final signature = path.endsWith('/complete') && body is Map
        ? body['expectedVersion']
        : body;
    final identity =
        '$_actor:$method:$path:${idempotent ? jsonEncode(signature) : ''}';
    final durable =
        idempotent && method == 'POST' && _durable(path) && _actor != null;
    String? key;
    if (durable) {
      if (!_journal.containsKey(identity)) {
        if (_journal.length >= 32) {
          throw const Failure(
            'COMMAND_QUEUE_FULL',
            'Cần kiểm tra các thao tác đang chờ xác nhận trước khi tiếp tục.',
          );
        }
        _journal[identity] = {
          'path': path,
          'body': jsonDecode(jsonEncode(body)),
          'key': const Uuid().v4(),
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        };
      }
      body = _journal[identity]!['body'];
      key = _journal[identity]!['key'] as String;
      await _persist();
      _check(epoch);
    } else if (idempotent) {
      key = _volatile.putIfAbsent(identity, () => const Uuid().v4());
    }
    String? sentToken;
    Future<Response<dynamic>> send() {
      _check(epoch);
      sentToken = _session?['accessToken'] as String?;
      return dio.request<dynamic>(
        path,
        data: bytes == null ? body : Stream<List<int>>.value(bytes),
        options: Options(
          method: method,
          contentType: contentType,
          headers: {
            if (sentToken != null) 'Authorization': 'Bearer $sentToken',
            'Idempotency-Key': ?key,
            if (bytes != null) 'Content-Length': bytes.length,
          },
        ),
      );
    }

    Future<void> finish() async {
      _volatile.remove(identity);
      if (durable) {
        _journal.remove(identity);
        await _persist();
      }
    }

    try {
      Response<dynamic> response;
      try {
        response = await send();
      } on DioException catch (e) {
        _check(epoch);
        if (e.response?.statusCode == 401 &&
            _session != null &&
            !path.startsWith('/auth/')) {
          if (sentToken == _session!['accessToken']) await _refresh();
          _check(epoch);
          response = await send();
        } else {
          rethrow;
        }
      }
      _check(epoch);
      await finish();
      return response.data;
    } on DioException catch (e) {
      _check(epoch);
      final raw = e.response?.data;
      final problem = raw is Map ? raw : const <String, dynamic>{};
      final status = e.response?.statusCode;
      if (status == 401 && _session != null && !path.startsWith('/auth/')) {
        await clear(expired: true);
        throw const Failure(
          'SESSION_EXPIRED',
          'Phiên đã hết hạn. Vui lòng đăng nhập lại.',
        );
      }
      if (status != null &&
          status < 500 &&
          problem['code'] != 'OPERATION_IN_PROGRESS') {
        await finish();
      }
      throw Failure(
        problem['code'] as String? ??
            (status == null ? 'NETWORK_ERROR' : 'HTTP_$status'),
        problem['title'] as String? ??
            (status == null
                ? 'Không kết nối được máy chủ. Thao tác chưa xác nhận được giữ để thử lại.'
                : 'Yêu cầu không được máy chủ chấp nhận.'),
      );
    }
  }
}
