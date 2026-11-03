import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import 'api_client.dart';
import 'dio_config.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(apiOptions(apiBaseUrl));
  ref.onDispose(() => dio.close(force: true));
  return dio;
});
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    apiBaseUrl,
    const FlutterSecureStorage(),
    transport: ref.watch(dioProvider),
  ),
);
