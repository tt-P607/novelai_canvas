import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/prompt_assistant.dart';

class PromptChatPreferences {
  PromptChatPreferences(this._preferences);

  static const _sessionsKey = 'prompt_chat_sessions_v1';
  static const _activeSessionKey = 'prompt_chat_active_session_v1';

  final SharedPreferences _preferences;

  List<PromptChatSession> loadSessions() {
    final raw = _preferences.getString(_sessionsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (value) =>
                PromptChatSession.fromJson(Map<String, Object?>.from(value)),
          )
          .where((session) => session.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveSessions(List<PromptChatSession> sessions) =>
      _preferences.setString(
        _sessionsKey,
        jsonEncode(sessions.map((session) => session.toJson()).toList()),
      );

  String? get activeSessionId => _preferences.getString(_activeSessionKey);

  Future<void> setActiveSessionId(String id) =>
      _preferences.setString(_activeSessionKey, id);
}
