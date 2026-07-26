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
    // An absolute path is an explicit host choice, such as the account-host
    // fallback used when a gateway only proxies the image API.
    if (options.path.startsWith('http://') ||
        options.path.startsWith('https://')) {
      handler.next(options);
      return;
    }
    final settings = _settingsProvider();
    final requestPath = options.uri.path;
    options.baseUrl = _accountPaths.contains(requestPath)
        ? NativeEndpointResolver.accountBaseUrl(settings)
        : NativeEndpointResolver.imageBaseUrl(settings);
    handler.next(options);
  }
}
