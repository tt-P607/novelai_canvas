import 'dart:convert';

import 'package:dio/dio.dart';

import '../errors/app_exception.dart';

abstract final class NetworkErrorMapper {
  static AppException map(Object error) {
    if (error is AppException) return error;
    if (error is! DioException) {
      return NetworkException('发生未知网络错误。', cause: error);
    }
    if (error.error is AppException) return error.error! as AppException;

    final statusCode = error.response?.statusCode;
    final body = error.response?.data;
    final message = _extractMessage(body) ?? error.message ?? '网络请求失败。';

    if (statusCode == 401) {
      return AuthenticationException(
        '认证失败：$message',
        cause: error,
        statusCode: statusCode,
        responseBody: body,
      );
    }

    return NetworkException(
      _statusPrefix(statusCode) + message,
      cause: error,
      statusCode: statusCode,
      responseBody: body,
    );
  }

  static String _statusPrefix(int? statusCode) {
    if (statusCode != null && statusCode >= 500) {
      return switch (statusCode) {
        503 => '服务队列繁忙：',
        504 => '请求超时：',
        _ => '服务器错误：',
      };
    }
    return switch (statusCode) {
      402 => 'Anlas 余额不足：',
      403 => '请求被拒绝：',
      409 => '请求冲突：',
      429 => '请求过于频繁：',
      _ => '',
    };
  }

  static String? _extractMessage(Object? body) {
    if (body is Map) {
      final error = body['error'];
      if (error is Map && error['message'] != null) {
        return error['message'].toString();
      }
      final detail = body['detail'];
      if (detail is String) return detail;
      if (detail != null) return jsonEncode(detail);
      if (body['message'] != null) return body['message'].toString();
    }
    if (body is String && body.trim().isNotEmpty) return body;
    return null;
  }
}
