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
    final extractedMessage = _extractMessage(body);
    final message =
        extractedMessage ??
        (statusCode == null ? _connectionMessage(error) : null) ??
        '网络请求失败。';

    if (statusCode == 401) {
      return AuthenticationException(
        '认证失败：$message',
        cause: error,
        statusCode: statusCode,
        responseBody: body,
      );
    }

    final resolvedMessage =
        statusCode == 404 &&
            (_isGenericDioMessage(message) ||
                message == '网络请求失败。' ||
                body == null)
        ? _notFoundMessage(error.requestOptions.path)
        : message;
    return NetworkException(
      _statusPrefix(statusCode) + resolvedMessage,
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

  static String _notFoundMessage(String path) {
    if (path.startsWith('/ai/') || path.startsWith('/user/')) {
      return '原生接口路径不存在。自定义接口会接收原始 NovelAI 路径；请确认设置中的 URL 正确，并且网关支持此路径。';
    }
    return 'OpenAI 接口路径不存在。请确认服务地址正确；地址末尾的 /v1 可省略，软件会自动补全。';
  }

  static bool _isGenericDioMessage(String message) =>
      message.contains('status code of 404') ||
      message.contains('validateStatus was configured');

  static String _connectionMessage(DioException error) {
    final uri = error.requestOptions.uri;
    final target = uri.hasAuthority ? '${uri.scheme}://${uri.authority}' : '';
    final suffix = target.isEmpty ? '' : '（目标：$target）';
    return switch (error.type) {
      DioExceptionType.connectionTimeout => '连接接口超时$suffix。',
      DioExceptionType.sendTimeout => '发送请求超时$suffix。',
      DioExceptionType.receiveTimeout => '等待接口响应超时$suffix。',
      DioExceptionType.connectionError => '无法连接到接口$suffix，请检查地址、端口和网络。',
      DioExceptionType.badCertificate => '接口 HTTPS 证书无效$suffix。',
      DioExceptionType.cancel => '请求已取消。',
      _ => '网络请求失败$suffix。',
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
