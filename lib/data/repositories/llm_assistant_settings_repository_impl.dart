import '../../domain/entities/llm_assistant_settings.dart';
import '../../domain/repositories/llm_assistant_settings_repository.dart';
import '../datasources/local/llm_assistant_preferences.dart';

class LlmAssistantSettingsRepositoryImpl
    implements LlmAssistantSettingsRepository {
  LlmAssistantSettingsRepositoryImpl(this._preferences);

  final LlmAssistantPreferences _preferences;

  @override
  Future<LlmAssistantSettings> load() async => _preferences.load();

  @override
  Future<void> save(LlmAssistantSettings settings) =>
      _preferences.save(settings);
}
