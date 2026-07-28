import 'dart:developer';

import 'package:dio/dio.dart';

import '../../domain/entities/app_settings.dart';
import '../errors/app_exception.dart';

/// Applies the configured gateway base URL to every request issued by the
/// gateway-format Dio client.
///
/// The gateway services receive a shared Dio instance whose `baseUrl` is left
/// empty at construction time; this interceptor resolves the live base URL on
/// each request so the same Dio can be reused after the user changes the
/// endpoint without re-registering services.
///
/// The base URL is normalised the same way [`ApiModeRouter`] does: trailing
/// slashes and a redundant `/v1` suffix are stripped, because gateway services
/// already prefix every path with `/v1/...`.
class GatewayEndpointInterceptor extends Interceptor {
  GatewayEndpointInterceptor({required AppSettings Function() settingsProvider})
    : _settingsProvider = settingsProvider;

  final AppSettings Function() _settingsProvider;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final settings = _settingsProvider();
    final baseUrl = _normalize(settings.effectiveBaseUrl);
    log(
      '[GatewayEndpointInterceptor] backendMode=${settings.backendMode} '
      'nativeUrl="${settings.nativeEndpointBaseUrl}" '
      'gatewayUrl="${settings.gatewayEndpointBaseUrl}" '
      '→ baseUrl="$baseUrl" path="${options.path}"',
    );
    // An empty base URL means the user switched to gateway mode without
    // saving an endpoint. Letting Dio proceed with an empty baseUrl causes
    // it to resolve the path against a null host, producing a misleading 404
    // instead of a clear configuration error.
    if (baseUrl.isEmpty) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: ConfigurationException('OpenAI 接口地址为空。请在设置中填写接口 URL 并保存。'),
        ),
      );
      return;
    }
    options.baseUrl = baseUrl;
    handler.next(options);
  }

  static String _normalize(String value) {
    // Users sometimes paste multi-line URLs; any whitespace (including
    // embedded newlines) would break Dio's URL composition, so collapse all
    // whitespace before trimming trailing slashes.
    var normalized = value.replaceAll(RegExp(r'\s+'), '');
    normalized = normalized.replaceAll(RegExp(r'/+$'), '');
    if (normalized.endsWith('/v1')) {
      normalized = normalized.substring(0, normalized.length - 3);
    }
    return normalized;
  }
}
