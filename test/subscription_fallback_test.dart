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
  test('自定义端点返回错误主机提示时，订阅查询回退到官方图片域名', () async {
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
      '${AppConstants.nativeBaseUrl}/user/subscription',
    );
  });

  test('提示以纯文本而非 JSON 对象返回时也会回退', () async {
    final adapter = _ScriptedAdapter([
      _RawReply(
        200,
        'Please refresh NovelAI.net. If using a third-party tool, '
        'update to the image URL.',
      ),
      _Reply(200, {'tier': 3, 'active': true}),
    ]);
    final service = NativeSubscriptionService(_client(adapter));

    expect((await service.getSubscription()).tier, 3);
    expect(adapter.requestedUrls.length, 2);
  });

  test('提示包在 HTML 页面里时也会回退', () async {
    final adapter = _ScriptedAdapter([
      _RawReply(
        200,
        '<html><body>Please refresh NovelAI.net. '
        'If using a third-party tool, update to the image URL.</body></html>',
      ),
      _Reply(200, {'tier': 3, 'active': true}),
    ]);
    final service = NativeSubscriptionService(_client(adapter));

    expect((await service.getSubscription()).tier, 3);
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

  test('网关返回其他错误码时也会回退，而不是直接失败', () async {
    for (final status in const [400, 403, 500, 502]) {
      final adapter = _ScriptedAdapter([
        _Reply(status, {'error': 'gateway cannot serve account routes'}),
        _Reply(200, {'tier': 3, 'active': true}),
      ]);
      final service = NativeSubscriptionService(_client(adapter));

      expect(
        (await service.getSubscription()).tier,
        3,
        reason: '状态码 $status 应触发回退',
      );
    }
  });

  test('两个地址都失败时，错误消息列出尝试过的主机', () async {
    final adapter = _ScriptedAdapter([
      _RawReply(
        200,
        'Please refresh NovelAI.net. If using a third-party tool, '
        'update to the image URL.',
      ),
      _Reply(500, {'message': 'boom'}),
    ]);
    final service = NativeSubscriptionService(_client(adapter));

    await expectLater(
      service.getSubscription(),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          allOf(contains('gateway.example.com'), contains('image.novelai.net')),
        ),
      ),
    );
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
