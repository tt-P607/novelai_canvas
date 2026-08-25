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
    // When the server replied with a status code but the body could not be
    // turned into a human message (e.g. an nginx/CDN HTML error page for a 502
    // that never reached the application layer), surface the status code and a
    // short body excerpt instead of the opaque "网络请求失败". Without this,
    // a reverse-proxy 5xx is indistinguishable from a transport failure, which
    // blocked root-cause analysis for gateway requests on Android.
    final message =
        extractedMessage ??
        (statusCode == null ? _connectionMessage(error) : null) ??
        _serverFailureMessage(statusCode, body);

    if (statusCode == 401) {
      return AuthenticationException(
        '认证失败：$message',
        cause: error,
        statusCode: statusCode,
        responseBody: body,
      );
    }

    final resolvedMessage =
        statusCode == 404 && (_isGenericDioMessage(message) || body == null)
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
    if (path.startsWith('/origin/') ||
        path.startsWith('/_api/') ||
        path.startsWith('/ai/') ||
        path.startsWith('/user/')) {
      return '原生接口路径不存在。自定义接口会接收原始 NovelAI 路径；请确认设置中的 URL 正确，并且网关支持此路径。';
    }
    if (path.startsWith('/v1/')) {
      return 'OpenAI 接口路径不存在。请确认服务地址正确；地址末尾的 /v1 可省略，软件会自动补全。';
    }
    return '接口路径不存在：$path';
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

  /// Fallback used when the server returned a status code but the body did not
  /// yield a structured message. Always includes the status code so the user
  /// can tell a 502 (reverse proxy) from a 500 (application), and appends a
  /// short body excerpt when one exists so non-JSON error pages are visible.
  static String _serverFailureMessage(int? statusCode, Object? body) {
    final code = statusCode ?? 0;
    final excerpt = _bodyExcerpt(body);
    if (excerpt.isEmpty) return '网络请求失败（HTTP $code）。';
    return '网络请求失败（HTTP $code，响应：$excerpt）。';
  }

  static String _bodyExcerpt(Object? body) {
    if (body == null) return '';
    String text;
    if (body is List<int>) {
      text = utf8.decode(body, allowMalformed: true);
    } else if (body is String) {
      text = body;
    } else if (body is ResponseBody) {
      // The bytes of a ResponseBody stream cannot be read synchronously here.
      // Callers that need the real text should drain it before mapping (see
      // GatewayApiService._drainStreamBody); otherwise show the type so the
      // status code at least distinguishes transport from application errors.
      text = '<${body.runtimeType}>';
    } else {
      try {
        text = jsonEncode(body);
      } catch (_) {
        text = '<${body.runtimeType}>';
      }
    }
    // Collapse whitespace so HTML error pages stay compact, and cap the length
    // so a multi-kilobyte nginx page does not flood the snackbar.
    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.length <= 200) return collapsed;
    return '${collapsed.substring(0, 200)}…';
  }
}
