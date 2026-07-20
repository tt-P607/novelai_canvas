import 'package:dio/dio.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/entities/backend_capabilities.dart';
import '../errors/app_exception.dart';
import 'backend_mode.dart';

class ApiModeRouter {
  ApiModeRouter({
    required Dio nativeClient,
    required Dio gatewayClient,
    required AppSettings Function() settingsProvider,
  }) : _nativeClient = nativeClient,
       _gatewayClient = gatewayClient,
       _settingsProvider = settingsProvider;

  final Dio _nativeClient;
  final Dio _gatewayClient;
  final AppSettings Function() _settingsProvider;

  BackendMode get activeMode => _settingsProvider().backendMode;

  BackendCapabilities get capabilities => switch (activeMode) {
    BackendMode.native => const BackendCapabilities.native(),
    BackendMode.gateway => const BackendCapabilities.gateway(),
  };

  Dio clientFor(BackendMode mode) {
    return switch (mode) {
      BackendMode.native => _nativeClient,
      BackendMode.gateway => _configuredGatewayClient(),
    };
  }

  Dio get activeClient => clientFor(activeMode);

  Dio _configuredGatewayClient() {
    final endpointBaseUrl = _settingsProvider().effectiveBaseUrl;
    if (endpointBaseUrl.isEmpty) {
      throw const ConfigurationException('请先配置 OpenAI 接口地址。');
    }
    _gatewayClient.options.baseUrl = _normalizeBaseUrl(endpointBaseUrl);
    return _gatewayClient;
  }

  String _normalizeBaseUrl(String value) {
    var normalized = value.trim().replaceAll(RegExp(r'/+$'), '');
    if (normalized.endsWith('/v1')) {
      normalized = normalized.substring(0, normalized.length - 3);
    }
    return normalized;
  }
}
