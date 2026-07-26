import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_canvas/core/errors/app_exception.dart';
import 'package:novelai_canvas/core/network/backend_mode.dart';
import 'package:novelai_canvas/core/network/native_endpoint_interceptor.dart';
import 'package:novelai_canvas/data/api/native/services/native_user_service.dart';
import 'package:novelai_canvas/domain/entities/app_settings.dart';

const _gatewaySettings = AppSettings(
  onboardingCompleted: true,
  backendMode: BackendMode.native,
  endpointBaseUrl: 'https://gateway.example.com',
);

void main() {
  test('订阅查询只发往配置的网关，绝不直连官方域名', () async {
    final adapter = _ScriptedAdapter([
      _Reply(200, {'tier': 3, 'active': true}),
    ]);
    final service = NativeSubscriptionService(_client(adapter));

    final info = await service.getSubscription();

    expect(info.tier, 3);
    expect(info.tierName, 'Opus');
    expect(adapter.requestedUrls, [
      'https://gateway.example.com/_api/user/subscription',
    ]);
  });

  test('网关返回错误主机提示时报配置错误，而不是绕过网关直连官方', () async {
    final adapter = _ScriptedAdapter([
      _RawReply(
        200,
        'Please refresh NovelAI.net. If using a third-party tool, '
        'update to the image URL.',
      ),
    ]);
    final service = NativeSubscriptionService(_client(adapter));

    await expectLater(
      service.getSubscription(),
      throwsA(
        isA<ConfigurationException>().having(
          (error) => error.message,
          'message',
          contains('image.novelai.net'),
        ),
      ),
    );
    // Exactly one request, and it stayed on the gateway.
    expect(adapter.requestedUrls, [
      'https://gateway.example.com/_api/user/subscription',
    ]);
  });

  test('网关返回错误状态码时直接失败，不发起第二次请求', () async {
    final adapter = _ScriptedAdapter([
      _Reply(404, {'error': 'not found'}),
    ]);
    final service = NativeSubscriptionService(_client(adapter));

    await expectLater(service.getSubscription(), throwsA(isA<Exception>()));
    expect(adapter.requestedUrls.length, 1);
  });
}

Dio _client(HttpClientAdapter adapter) {
  final dio = Dio()
    ..interceptors.add(
      NativeEndpointInterceptor(settingsProvider: () => _gatewaySettings),
    )
    ..httpClientAdapter = adapter;
  return dio;
}

sealed class _Response {
  const _Response();

  ResponseBody toBody();
}

class _Reply extends _Response {
  const _Reply(this.statusCode, this.body);

  final int statusCode;
  final Map<String, Object?> body;

  @override
  ResponseBody toBody() => ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

/// Non-JSON payloads, such as the plain-text notice or an HTML error page.
class _RawReply extends _Response {
  const _RawReply(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  ResponseBody toBody() => ResponseBody.fromString(
    body,
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['text/plain'],
    },
  );
}

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._replies);

  final List<_Response> _replies;
  final List<String> requestedUrls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedUrls.add(options.uri.toString());
    return _replies[requestedUrls.length - 1].toBody();
  }

  @override
  void close({bool force = false}) {}
}
