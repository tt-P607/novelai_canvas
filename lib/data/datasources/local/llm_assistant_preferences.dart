import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/llm_assistant_settings.dart';

class LlmAssistantPreferences {
  LlmAssistantPreferences(this._preferences);

  static const _settingsKey = 'llm_assistant_settings_v1';

  final SharedPreferences _preferences;

  LlmAssistantSettings load() {
    final raw = _preferences.getString(_settingsKey);
    if (raw == null || raw.isEmpty) return const LlmAssistantSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return LlmAssistantSettings.fromJson(
          Map<String, Object?>.from(decoded),
        );
      }
    } catch (_) {
      return const LlmAssistantSettings();
    }
    return const LlmAssistantSettings();
  }

  Future<void> save(LlmAssistantSettings settings) =>
      _preferences.setString(_settingsKey, jsonEncode(settings.toJson()));
}
