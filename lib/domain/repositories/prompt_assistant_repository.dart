import '../entities/llm_assistant_settings.dart';
import '../entities/prompt_assistant.dart';

abstract interface class PromptAssistantRepository {
  Future<ExtractedKeywords> extractKeywords({
    required String description,
    required LlmAssistantSettings settings,
  });

  Future<DanbooruTagPool> searchTags({
    required ExtractedKeywords keywords,
    required LlmAssistantSettings settings,
  });

  Future<PromptAssistantResult> compose({
    required String description,
    required ExtractedKeywords keywords,
    required DanbooruTagPool tagPool,
    required String currentPositive,
    required String currentNegative,
    required LlmAssistantSettings settings,
  });

  Future<String> analyzeImage({
    required String imagePath,
    required String instruction,
    required LlmAssistantSettings settings,
  });
}
