import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_canvas/data/datasources/local/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novelai_canvas/core/constants/app_constants.dart';
import 'package:novelai_canvas/core/network/backend_mode.dart';
import 'package:novelai_canvas/domain/entities/app_settings.dart';
import 'package:novelai_canvas/domain/entities/prompt_assistant.dart';

void main() {
  test(
    'initial settings use editable official native URL and require onboarding',
    () {
      const settings = AppSettings.initial();

      expect(settings.onboardingCompleted, isFalse);
      expect(settings.backendMode, BackendMode.native);
      expect(settings.nativeEndpointBaseUrl, AppConstants.nativeBaseUrl);
      expect(settings.activeEndpoint.mode, BackendMode.native);
    },
  );

  test('gateway endpoint follows configured base URL', () {
    final settings = const AppSettings.initial().copyWith(
      backendMode: BackendMode.gateway,
      gatewayEndpointBaseUrl: 'https://gateway.example.com',
    );

    expect(settings.activeEndpoint.mode, BackendMode.gateway);
    expect(settings.activeEndpoint.baseUrl, 'https://gateway.example.com');
  });

  test('legacy empty native URL loads as the editable official default', () {
    final settings = AppSettings.fromJson(const {
      'onboarding_completed': true,
      'backend_mode': 'native',
      'endpoint_base_url': '',
    });

    expect(settings.effectiveBaseUrl, AppConstants.nativeBaseUrl);
  });

  test('原生与网关各保存独立 URL，互不影响', () {
    final settings = const AppSettings.initial().copyWith(
      backendMode: BackendMode.gateway,
      gatewayEndpointBaseUrl: 'https://gateway.example.com',
    );

    expect(
      settings.endpointBaseUrlFor(BackendMode.gateway),
      'https://gateway.example.com',
    );
    expect(
      settings.endpointBaseUrlFor(BackendMode.native),
      AppConstants.nativeBaseUrl,
    );
  });

  test('提示词助手消息序列化后保留可重复填入的提示词结果', () {
    final createdAt = DateTime.utc(2026, 7, 20, 2, 30);
    final original = PromptChatMessage(
      role: PromptChatRole.assistant,
      content: '提示词已经整理完成。',
      createdAt: createdAt,
      promptResult: const PromptAssistantResult(
        positive: '1girl, pink hair',
        negative: 'lowres',
        characters: [
          ComposedCharacterPrompt(
            prompt: 'elysia, pink hair',
            negativePrompt: 'bad hands',
            x: 0.4,
            y: 0.5,
          ),
        ],
      ),
    );

    final restored = PromptChatMessage.fromJson(original.toJson());

    expect(restored, original);
    expect(restored.promptResult?.positive, '1girl, pink hair');
    expect(restored.promptResult?.characters.single.x, 0.4);
  });
  test('流式生成开关持久化', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = AppPreferences(await SharedPreferences.getInstance());

    expect(preferences.streamGenerationEnabled, isFalse);
    await preferences.setStreamGenerationEnabled(true);

    final restored = AppPreferences(await SharedPreferences.getInstance());
    expect(restored.streamGenerationEnabled, isTrue);
  });

  test('订阅等级与检查时间持久化，重启后可直接恢复', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = AppPreferences(await SharedPreferences.getInstance());

    expect(preferences.subscriptionTier, isNull);
    expect(preferences.subscriptionCheckedAt, isNull);

    final checkedAt = DateTime(2026, 7, 26, 12);
    await preferences.setSubscriptionTier(3, checkedAt);

    final restored = AppPreferences(await SharedPreferences.getInstance());
    expect(restored.subscriptionTier, 3);
    expect(restored.subscriptionCheckedAt, checkedAt);
  });
}
