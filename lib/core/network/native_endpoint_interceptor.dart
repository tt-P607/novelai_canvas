import 'dart:developer';

import 'package:dio/dio.dart';

import '../../domain/entities/app_settings.dart';
import 'native_endpoint_resolver.dart';

/// Applies the currently selected native-format endpoint to every request.
///
/// Custom endpoints receive all paths unchanged. The built-in official
/// endpoint is the only configuration that splits account/upscale requests to
/// api.novelai.net while keeping generation requests on image.novelai.net.
class NativeEndpointInterceptor extends Interceptor {
  NativeEndpointInterceptor({required AppSettings Function() settingsProvider})
    : _settingsProvider = settingsProvider;

  final AppSettings Function() _settingsProvider;

  /// Paths served by api.novelai.net. `/ai/upscale` and `/ai/generate-voice`
  /// look like image endpoints but live on the account host, so they must be
  /// matched before any generic `/ai/` handling.
  ///
  /// `/user/*` deliberately stays on image.novelai.net: authenticated requests
  /// to api.novelai.net now answer with the "update to the image URL" notice,
  /// and the working novelai-sdk reads the subscription from the image host.
  static const _accountPaths = <String>{'/ai/upscale', '/ai/generate-voice'};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Every native request goes through the configured endpoint; there is no
    // absolute-URL escape hatch. A gateway user must never see the client
    // silently contacting official NovelAI hosts behind their back.
    final settings = _settingsProvider();
    final requestPath = options.uri.path;
    final baseUrl = _accountPaths.contains(requestPath)
        ? NativeEndpointResolver.accountBaseUrl(settings)
        : NativeEndpointResolver.imageBaseUrl(settings);
    log(
      '[NativeEndpointInterceptor] backendMode=${settings.backendMode} '
      '→ baseUrl="$baseUrl" path="${options.path}"',
    );
    options.baseUrl = baseUrl;
    handler.next(options);
  }
}
