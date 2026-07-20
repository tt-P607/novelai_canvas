import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract final class AppConstants {
  static const appName = 'NovelAI Canvas · 绘境';
  static const shortAppName = 'NovelAI Canvas';

  static const nativeBaseUrl = 'https://image.novelai.net';
  static const nativeUserBaseUrl = 'https://api.novelai.net';

  static const endpointBaseUrlPreferenceKey = 'endpoint_base_url';
  static const gatewayBaseUrlPreferenceKey = 'gateway_base_url';
  static const backendModePreferenceKey = 'backend_mode';
  static const onboardingCompletedPreferenceKey = 'onboarding_completed';

  static const imageApiCredentialKey = 'image_api_key';
  static const novelAiCredentialKey = 'novelai_token';
  static const gatewayCredentialKey = 'gateway_api_key';
  static const llmCredentialKey = 'llm_api_key';

  static Future<void> migrateImageCredential(
    FlutterSecureStorage storage,
  ) async {
    final current = await storage.read(key: imageApiCredentialKey);
    if (current != null && current.trim().isNotEmpty) return;
    final legacyNative = await storage.read(key: novelAiCredentialKey);
    final legacyGateway = await storage.read(key: gatewayCredentialKey);
    final migrated = legacyNative?.trim().isNotEmpty == true
        ? legacyNative!.trim()
        : legacyGateway?.trim() ?? '';
    if (migrated.isNotEmpty) {
      await storage.write(key: imageApiCredentialKey, value: migrated);
    }
  }
}
