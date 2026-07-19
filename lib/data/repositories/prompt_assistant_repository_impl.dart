import 'dart:convert';
import 'dart:io';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../domain/entities/llm_assistant_settings.dart';
import '../../domain/entities/prompt_assistant.dart';
import '../../domain/repositories/prompt_assistant_repository.dart';
import '../../domain/repositories/secure_credential_store.dart';
import '../api/danbooru/danbooru_service.dart';
import '../api/llm/llm_chat_service.dart';

class PromptAssistantRepositoryImpl implements PromptAssistantRepository {
  PromptAssistantRepositoryImpl({
    required LlmChatService llmService,
    required DanbooruService danbooruService,
    required SecureCredentialStore credentialStore,
  }) : _llmService = llmService,
       _danbooruService = danbooruService,
       _credentialStore = credentialStore;

  final LlmChatService _llmService;
  final DanbooruService _danbooruService;
  final SecureCredentialStore _credentialStore;

  @override
  Future<ExtractedKeywords> extractKeywords({
    required String description,
    required LlmAssistantSettings settings,
  }) async {
    final reply = await _complete(
      settings: settings,
      model: settings.model,
      messages: [
        {'role': 'system', 'content': settings.prompts.keywordExtraction},
        {'role': 'user', 'content': description.trim()},
      ],
    );
    final json = await _parseJson(reply, settings: settings);
    final keywords = ExtractedKeywords.fromJson(json);
    return keywords.isEmpty
        ? ExtractedKeywords(characters: [description.trim()])
        : keywords;
  }

  @override
  Future<DanbooruTagPool> searchTags({
    required ExtractedKeywords keywords,
    required LlmAssistantSettings settings,
  }) async {
    final globalQueries = [
      ...keywords.scene,
      ...keywords.style,
      if (settings.showNsfw) ...keywords.nsfw,
    ];
    final globalResults = await Future.wait(
      globalQueries.map(
        (query) => _safeSearch(query, settings: settings, limit: 12),
      ),
    );
    final characterResults = await Future.wait(
      keywords.characters.map(
        (query) => _characterTags(query, settings: settings),
      ),
    );
    final pool = DanbooruTagPool(
      globalTags: _merge(globalResults.expand((tags) => tags)),
      perCharacterTags: characterResults,
    );
    if (pool.isEmpty) {
      throw StateError('Danbooru 检索没有返回真实标签。');
    }
    return pool;
  }

  @override
  Future<PromptAssistantResult> compose({
    required String description,
    required ExtractedKeywords keywords,
    required DanbooruTagPool tagPool,
    required String currentPositive,
    required String currentNegative,
    required LlmAssistantSettings settings,
  }) async {
    final poolJson = {
      'global': tagPool.globalTags.map(_tagJson).toList(),
      'characters': tagPool.perCharacterTags
          .map((tags) => tags.map(_tagJson).toList())
          .toList(),
    };
    final reply = await _complete(
      settings: settings,
      model: settings.model,
      messages: [
        {'role': 'system', 'content': settings.prompts.promptComposition},
        {
          'role': 'user',
          'content': jsonEncode({
            'description': description,
            'keywords': keywords.toJson(),
            'candidate_pool': poolJson,
            'current_positive': currentPositive,
            'current_negative': currentNegative,
          }),
        },
      ],
    );
    return PromptAssistantResult.fromJson(
      await _parseJson(reply, settings: settings),
    );
  }

  @override
  Future<String> analyzeImage({
    required String imagePath,
    required String instruction,
    required LlmAssistantSettings settings,
  }) async {
    if (settings.visionModel.trim().isEmpty) {
      throw const ConfigurationException('请先配置支持 Vision/多模态输入的模型。普通文本模型不能识图。');
    }
    final bytes = await File(imagePath).readAsBytes();
    final extension = imagePath.split('.').last.toLowerCase();
    final mime = extension == 'png' ? 'image/png' : 'image/jpeg';
    final reply = await _complete(
      settings: settings,
      model: settings.visionModel,
      messages: [
        {'role': 'system', 'content': settings.prompts.visionAnalysis},
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': instruction.trim().isEmpty
                  ? '分析这张图片并提取可见画面信息。'
                  : instruction.trim(),
            },
            {
              'type': 'image_url',
              'image_url': {'url': 'data:$mime;base64,${base64Encode(bytes)}'},
            },
          ],
        },
      ],
    );
    final json = await _parseJson(reply, settings: settings);
    final description = json['description']?.toString().trim() ?? '';
    if (description.isNotEmpty) return description;
    final fragments = [
      ..._stringList(json['characters']),
      ..._stringList(json['scene']),
      ..._stringList(json['style']),
    ];
    if (fragments.isNotEmpty) return fragments.join('，');
    throw const DataParsingException('Vision 模型没有返回可用的画面描述。');
  }

  Future<String> _complete({
    required LlmAssistantSettings settings,
    required String model,
    required List<Map<String, Object?>> messages,
  }) async {
    final apiKey =
        await _credentialStore.read(AppConstants.llmCredentialKey) ?? '';
    return _llmService.complete(
      baseUrl: settings.baseUrl,
      apiKey: apiKey,
      model: model,
      messages: messages,
    );
  }

  Future<Map<String, Object?>> _parseJson(
    String value, {
    required LlmAssistantSettings settings,
  }) async {
    final direct = _tryJson(value);
    if (direct != null) return direct;
    final repaired = await _complete(
      settings: settings,
      model: settings.model,
      messages: [
        {'role': 'system', 'content': settings.prompts.jsonRepair},
        {'role': 'user', 'content': value},
      ],
    );
    final result = _tryJson(repaired);
    if (result != null) return result;
    throw const DataParsingException('模型输出无法修复为合法 JSON。');
  }

  Map<String, Object?>? _tryJson(String value) {
    var cleaned = value.trim();
    if (cleaned.startsWith('```')) {
      final newline = cleaned.indexOf('\n');
      if (newline >= 0) cleaned = cleaned.substring(newline + 1);
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
    }
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) cleaned = cleaned.substring(start, end + 1);
    try {
      final decoded = jsonDecode(cleaned);
      return decoded is Map ? Map<String, Object?>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<List<DanbooruTag>> _safeSearch(
    String query, {
    required LlmAssistantSettings settings,
    required int limit,
  }) async {
    if (query.trim().isEmpty) return const [];
    try {
      return await _danbooruService.search(
        query: query,
        showNsfw: settings.showNsfw,
        customBaseUrl: settings.danbooruBaseUrl,
        limit: limit,
      );
    } catch (_) {
      return const [];
    }
  }

  Future<List<DanbooruTag>> _characterTags(
    String query, {
    required LlmAssistantSettings settings,
  }) async {
    final searched = await _safeSearch(query, settings: settings, limit: 18);
    if (searched.isEmpty) return const [];
    try {
      final related = await _danbooruService.related(
        tags: searched.take(5).map((tag) => tag.tag).toList(),
        showNsfw: settings.showNsfw,
        customBaseUrl: settings.danbooruBaseUrl,
        limit: 18,
      );
      return _merge([...searched, ...related]);
    } catch (_) {
      return searched;
    }
  }

  List<DanbooruTag> _merge(Iterable<DanbooruTag> values) {
    final seen = <String>{};
    return values.where((tag) {
      final key = tag.tag.toLowerCase().replaceAll('_', ' ').trim();
      return key.isNotEmpty && seen.add(key);
    }).toList();
  }

  Map<String, Object?> _tagJson(DanbooruTag tag) => {
    'tag': tag.tag,
    'cn_name': tag.cnName,
    'category': tag.category,
    'count': tag.count,
    'score': tag.score,
  };

  List<String> _stringList(Object? value) => value is List
      ? value
            .map((item) => item?.toString().trim() ?? '')
            .where((item) => item.isNotEmpty)
            .toList()
      : const [];
}
