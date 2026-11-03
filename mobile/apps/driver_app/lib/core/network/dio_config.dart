import 'package:dio/dio.dart';

BaseOptions apiOptions(String baseUrl) => BaseOptions(
  baseUrl: '$baseUrl/api/v1',
  connectTimeout: const Duration(seconds: 12),
  receiveTimeout: const Duration(seconds: 20),
  headers: {'Content-Type': 'application/json'},
);
