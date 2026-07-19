import '../entities/llm_assistant_settings.dart';

abstract interface class LlmAssistantSettingsRepository {
  Future<LlmAssistantSettings> load();

  Future<void> save(LlmAssistantSettings settings);
}
