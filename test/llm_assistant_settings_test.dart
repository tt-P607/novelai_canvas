import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_canvas/data/datasources/local/llm_assistant_preferences.dart';
import 'package:novelai_canvas/domain/entities/llm_assistant_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('LLM 设置与四套 Prompt 可持久化并恢复默认', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = LlmAssistantPreferences(
      await SharedPreferences.getInstance(),
    );
    final settings =
        const LlmAssistantSettings(
          providerName: '测试服务',
          baseUrl: 'https://llm.example.com',
          model: 'small-model',
          visionModel: 'vision-model',
        ).copyWith(
          prompts: const PromptTemplateSet().update(
            PromptTemplateKind.keywordExtraction,
            'custom keyword prompt',
          ),
        );

    await preferences.save(settings);
    final restored = preferences.load();

    expect(restored, settings);
    expect(
      restored.prompts
          .reset(PromptTemplateKind.keywordExtraction)
          .keywordExtraction,
      PromptTemplateDefaults.keywordExtraction,
    );
    expect(jsonEncode(restored.toJson()), isNot(contains('api_key')));
  });
}
