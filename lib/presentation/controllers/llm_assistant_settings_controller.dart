import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/llm_assistant_settings.dart';
import '../../domain/repositories/llm_assistant_settings_repository.dart';
import '../../domain/repositories/secure_credential_store.dart';

class LlmAssistantSettingsController extends ChangeNotifier {
  LlmAssistantSettingsController({
    required LlmAssistantSettingsRepository repository,
    required SecureCredentialStore credentialStore,
    required LlmAssistantSettings initialSettings,
  }) : _repository = repository,
       _credentialStore = credentialStore,
       settings = initialSettings;

  final LlmAssistantSettingsRepository _repository;
  final SecureCredentialStore _credentialStore;

  LlmAssistantSettings settings;

  Future<void> applyImportedSettings(LlmAssistantSettings imported) async {
    settings = imported;
    await _repository.save(settings);
    notifyListeners();
  }

  Future<String> loadApiKey() async =>
      await _credentialStore.read(AppConstants.llmCredentialKey) ?? '';

  Future<void> saveConnection({
    required String providerName,
    required String baseUrl,
    required String model,
    required String visionModel,
    required String danbooruBaseUrl,
    required bool showNsfw,
    required String apiKey,
  }) async {
    settings = settings.copyWith(
      providerName: providerName.trim(),
      baseUrl: _normalizeBaseUrl(baseUrl),
      model: model.trim(),
      visionModel: visionModel.trim(),
      danbooruBaseUrl: _normalizeOptionalBaseUrl(danbooruBaseUrl),
      showNsfw: showNsfw,
    );
    await _repository.save(settings);
    if (apiKey.trim().isEmpty) {
      await _credentialStore.delete(AppConstants.llmCredentialKey);
    } else {
      await _credentialStore.write(
        key: AppConstants.llmCredentialKey,
        value: apiKey.trim(),
      );
    }
    notifyListeners();
  }

  Future<void> updatePrompt(PromptTemplateKind kind, String value) async {
    final prompt = value.trim().isEmpty
        ? PromptTemplateDefaults.valueOf(kind)
        : value.trim();
    settings = settings.copyWith(
      prompts: settings.prompts.update(kind, prompt),
    );
    await _repository.save(settings);
    notifyListeners();
  }

  Future<void> resetPrompt(PromptTemplateKind kind) async {
    settings = settings.copyWith(prompts: settings.prompts.reset(kind));
    await _repository.save(settings);
    notifyListeners();
  }

  String _normalizeBaseUrl(String value) {
    var normalized = value.trim().replaceAll(RegExp(r'/+$'), '');
    if (normalized.endsWith('/v1')) {
      normalized = normalized.substring(0, normalized.length - 3);
    }
    return normalized;
  }

  String _normalizeOptionalBaseUrl(String value) =>
      value.trim().replaceAll(RegExp(r'/+$'), '');
}
