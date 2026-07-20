import 'package:dio/dio.dart';

import '../entities/llm_assistant_settings.dart';
import '../entities/prompt_assistant.dart';

abstract interface class PromptAssistantRepository {
  Future<PromptAssistantReply> chat({
    required List<PromptChatMessage> messages,
    required String currentPositive,
    required String currentNegative,
    required LlmAssistantSettings settings,
    CancelToken? cancelToken,
    void Function(String status)? onStatus,
    void Function(String notice)? onNotice,
  });
}
