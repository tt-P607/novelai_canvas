import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_canvas/core/constants/app_constants.dart';
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
  test('网关只代理图片域名时，订阅查询回退到官方账户域名', () async {
    final adapter = _ScriptedAdapter([
      // NovelAI answers with 200 and a notice rather than an error status.
      _Reply(200, {
        'message':
            'Please refresh NovelAI.net. If using a third-party tool, '
            'update to the image URL.',
      }),
      _Reply(200, {'tier': 3, 'active': true}),
    ]);
    final service = NativeSubscriptionService(_client(adapter));

    final info = await service.getSubscription();

    expect(info.tier, 3);
    expect(info.tierName, 'Opus');
    expect(
      adapter.requestedUrls.first,
      'https://gateway.example.com/_api/user/subscription',
    );
    expect(
      adapter.requestedUrls.last,
      '${AppConstants.nativeUserBaseUrl}/user/subscription',
    );
  });

  test('网关返回 404 时同样回退', () async {
    final adapter = _ScriptedAdapter([
      _Reply(404, {'error': 'not found'}),
      _Reply(200, {'tier': 3, 'active': true}),
    ]);
    final service = NativeSubscriptionService(_client(adapter));

    expect((await service.getSubscription()).tier, 3);
    expect(adapter.requestedUrls.length, 2);
  });

  test('网关能正常返回订阅时不发起第二次请求', () async {
    final adapter = _ScriptedAdapter([
      _Reply(200, {'tier': 1, 'active': true}),
    ]);
    final service = NativeSubscriptionService(_client(adapter));

    expect((await service.getSubscription()).tier, 1);
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

class _Reply {
  const _Reply(this.statusCode, this.body);

  final int statusCode;
  final Map<String, Object?> body;
}

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._replies);

  final List<_Reply> _replies;
  final List<String> requestedUrls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedUrls.add(options.uri.toString());
    final reply = _replies[requestedUrls.length - 1];
    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
