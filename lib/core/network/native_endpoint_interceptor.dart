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

  static const _accountPaths = <String>{
    '/user/data',
    '/user/subscription',
    '/ai/upscale',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final settings = _settingsProvider();
    final requestPath = options.uri.path;
    options.baseUrl = _accountPaths.contains(requestPath)
        ? NativeEndpointResolver.accountBaseUrl(settings)
        : NativeEndpointResolver.imageBaseUrl(settings);
    handler.next(options);
  }
}
