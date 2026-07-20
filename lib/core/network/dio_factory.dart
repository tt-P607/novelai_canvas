import 'package:dio/dio.dart';

abstract final class DioFactory {
  static Dio createNative() =>
      _create(receiveTimeout: const Duration(minutes: 5));

  static Dio createGateway() =>
      _create(receiveTimeout: const Duration(minutes: 5));

  static Dio _create({
    String? baseUrl,
    Duration receiveTimeout = const Duration(seconds: 60),
  }) {
    return Dio(
      BaseOptions(
        baseUrl: baseUrl ?? '',
        connectTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: receiveTimeout,
        headers: const {
          'Accept':
              'application/json, application/octet-stream, application/zip',
          'User-Agent': 'NovelAI-Canvas/1.0',
        },
      ),
    );
  }
}
