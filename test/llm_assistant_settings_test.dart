import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_canvas/data/datasources/local/llm_assistant_preferences.dart';
import 'package:novelai_canvas/domain/entities/llm_assistant_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('LLM 设置与 Agent Prompt 可持久化并恢复默认', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = LlmAssistantPreferences(
      await SharedPreferences.getInstance(),
    );
    final settings =
        const LlmAssistantSettings(
          providerName: '测试服务',
          baseUrl: 'https://llm.example.com',
          model: 'small-model',
          danbooruToolsEnabled: false,
        ).copyWith(
          prompts: const PromptTemplateSet(agentPrompt: 'custom agent prompt'),
        );

    await preferences.save(settings);
    final restored = preferences.load();

    expect(restored, settings);
    expect(restored.prompts.agentPrompt, 'custom agent prompt');
    expect(restored.danbooruToolsEnabled, isFalse);

    final reset = restored.copyWith(prompts: const PromptTemplateSet());
    expect(reset.prompts.agentPrompt, PromptTemplateDefaults.agentPrompt);

    expect(jsonEncode(restored.toJson()), isNot(contains('api_key')));
  });

  test('Danbooru 工具开关默认开启', () {
    expect(const LlmAssistantSettings().danbooruToolsEnabled, isTrue);
  });
}
