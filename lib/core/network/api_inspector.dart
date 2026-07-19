import 'dart:convert';

import 'package:dio/dio.dart';

class ApiInspectionEntry {
  const ApiInspectionEntry({
    required this.timestamp,
    required this.method,
    required this.uri,
    this.requestHeaders,
    this.requestBody,
    this.statusCode,
    this.responseBody,
    this.elapsed,
    this.error,
  });

  final DateTime timestamp;
  final String method;
  final Uri uri;
  final Map<String, dynamic>? requestHeaders;
  final Object? requestBody;
  final int? statusCode;
  final Object? responseBody;
  final Duration? elapsed;
  final String? error;
}

class ApiInspector extends Interceptor {
  ApiInspector({this.capacity = 100});

  final int capacity;
  final List<ApiInspectionEntry> _entries = [];
  final Map<RequestOptions, DateTime> _startedAt = {};

  List<ApiInspectionEntry> get entries => List.unmodifiable(_entries);

  void clear() {
    _entries.clear();
    _startedAt.clear();
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _startedAt[options] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final options = response.requestOptions;
    final startedAt = _startedAt.remove(options);
    _add(
      ApiInspectionEntry(
        timestamp: startedAt ?? DateTime.now(),
        method: options.method,
        uri: options.uri,
        requestHeaders: _redactMap(options.headers),
        requestBody: _sanitize(options.data),
        statusCode: response.statusCode,
        responseBody: _sanitize(response.data),
        elapsed: startedAt == null
            ? null
            : DateTime.now().difference(startedAt),
      ),
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    final startedAt = _startedAt.remove(options);
    _add(
      ApiInspectionEntry(
        timestamp: startedAt ?? DateTime.now(),
        method: options.method,
        uri: options.uri,
        requestHeaders: _redactMap(options.headers),
        requestBody: _sanitize(options.data),
        statusCode: err.response?.statusCode,
        responseBody: _sanitize(err.response?.data),
        elapsed: startedAt == null
            ? null
            : DateTime.now().difference(startedAt),
        error: err.message,
      ),
    );
    handler.next(err);
  }

  void _add(ApiInspectionEntry entry) {
    _entries.add(entry);
    if (_entries.length > capacity) {
      _entries.removeRange(0, _entries.length - capacity);
    }
  }

  Map<String, dynamic> _redactMap(Map<String, dynamic> input) {
    return input.map((key, value) {
      final lowerKey = key.toLowerCase();
      if (lowerKey.contains('authorization') ||
          lowerKey.contains('token') ||
          lowerKey.contains('cookie') ||
          lowerKey.contains('api-key') ||
          lowerKey.contains('apikey')) {
        return MapEntry(key, '***');
      }
      return MapEntry(key, _sanitize(value));
    });
  }

  Object? _sanitize(Object? value, {int depth = 0}) {
    if (value == null || value is num || value is bool) return value;
    if (depth >= 5) return '<max-depth>';
    if (value is String) {
      if (value.startsWith('data:image/') || value.length > 2048) {
        return '<omitted:${utf8.encode(value).length} bytes>';
      }
      return value;
    }
    if (value is List<int>) return '<binary:${value.length} bytes>';
    if (value is List) {
      return value.map((item) => _sanitize(item, depth: depth + 1)).toList();
    }
    if (value is Map) {
      return value.map((key, item) {
        final stringKey = key.toString();
        final lowerKey = stringKey.toLowerCase();
        if (lowerKey.contains('key') ||
            lowerKey.contains('token') ||
            lowerKey.contains('cookie') ||
            lowerKey == 'image' ||
            lowerKey == 'mask') {
          return MapEntry(stringKey, '***');
        }
        return MapEntry(stringKey, _sanitize(item, depth: depth + 1));
      });
    }
    return value.toString();
  }
}
