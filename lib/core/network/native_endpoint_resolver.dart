import '../../domain/entities/app_settings.dart';
import '../constants/app_constants.dart';

/// Resolves request bases for the NovelAI-native request format.
///
/// A user-provided endpoint always wins and receives every native-format
/// request. Only the built-in official endpoint is split between NovelAI's
/// image and account API hosts.
abstract final class NativeEndpointResolver {
  static String imageBaseUrl(AppSettings settings) {
    final endpoint = _normalizeBase(settings.effectiveBaseUrl);
    if (_isOfficialEndpoint(endpoint)) {
      return AppConstants.nativeBaseUrl;
    }
    return _withGatewayPrefix(endpoint);
  }

  static String accountBaseUrl(AppSettings settings) {
    final endpoint = _normalizeBase(settings.effectiveBaseUrl);
    if (_isOfficialEndpoint(endpoint)) {
      return AppConstants.nativeUserBaseUrl;
    }
    return _withGatewayPrefix(endpoint);
  }

  /// Official defaults retain NovelAI's required host split. Any other URL is
  /// treated as the native-format gateway documented by novelai-gateway, whose
  /// transparent NovelAI proxy is mounted under `/_api`.
  static bool _isOfficialEndpoint(String endpoint) {
    return endpoint == _normalize(AppConstants.nativeBaseUrl) ||
        endpoint == _normalize(AppConstants.nativeUserBaseUrl);
  }

  static String _withGatewayPrefix(String endpoint) {
    if (endpoint.endsWith('/_api')) return endpoint;
    return '$endpoint/_api';
  }

  static String _normalizeBase(String value) {
    var normalized = value.trim().replaceAll(RegExp(r'/+$'), '');
    for (final suffix in const [
      '/ai/generate-image-stream',
      '/ai/generate-image',
      '/ai/augment-image',
      '/ai/upscale',
      '/user/subscription',
      '/user/data',
    ]) {
      if (normalized.endsWith(suffix)) {
        normalized = normalized.substring(0, normalized.length - suffix.length);
        break;
      }
    }
    return normalized.replaceAll(RegExp(r'/+$'), '');
  }

  static String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'/+$'), '');
}
