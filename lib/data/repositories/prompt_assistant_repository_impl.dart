import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../domain/entities/llm_assistant_settings.dart';
import '../../domain/entities/prompt_assistant.dart';
import '../../domain/repositories/prompt_assistant_repository.dart';
import '../../domain/repositories/secure_credential_store.dart';
import '../api/danbooru/danbooru_service.dart';
import '../api/llm/llm_chat_service.dart';
import 'prompt_assistant_tools.dart';

/// Maximum model round-trips before the agent gives up on a tool workflow.
const _maxAgentRounds = 6;

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
  Future<PromptAssistantReply> chat({
    required List<PromptChatMessage> messages,
    required String currentPositive,
    required String currentNegative,
    required LlmAssistantSettings settings,
    CancelToken? cancelToken,
    void Function(String status)? onStatus,
    void Function(String notice)? onNotice,
  }) async {
    if (messages.isEmpty) {
      throw const ConfigurationException('请先输入消息或添加图片。');
    }
    final session = _AgentSession(
      settings: settings,
      cancelToken: cancelToken,
      onStatus: onStatus,
      onNotice: onNotice,
    );
    final apiKey =
        await _credentialStore.read(AppConstants.llmCredentialKey) ?? '';
    final conversation = <Map<String, Object?>>[
      ..._systemMessages(settings, currentPositive, currentNegative),
      ...await Future.wait(messages.map(_messagePayload)),
    ];

    for (var round = 0; round < _maxAgentRounds; round++) {
      session.throwIfCancelled();
      onStatus?.call(round == 0 ? '正在请求模型…' : '正在等待模型整理结果…');
      final result = await _llmService.completeWithTools(
        baseUrl: settings.baseUrl,
        apiKey: apiKey,
        model: settings.model,
        messages: conversation,
        tools: session.availableTools,
        cancelToken: cancelToken,
      );
      if (result.reasoningContent.isNotEmpty) onStatus?.call('模型正在思考…');

      if (result.toolCalls.isEmpty) return _plainReply(result.content);

      conversation.add(_assistantToolCallMessage(result));
      final reply = await _runToolCalls(
        calls: result.toolCalls,
        assistantContent: result.content,
        conversation: conversation,
        session: session,
      );
      if (reply != null) return reply;
    }
    return const PromptAssistantReply(
      message: '模型未能完成本次工具流程，请关闭标签查询工具后重试，或换用支持 OpenAI Tool Calling 的模型。',
    );
  }

  /// Executes every tool call of one round, appending results to the
  /// conversation. Returns a reply as soon as the model submits a final prompt.
  Future<PromptAssistantReply?> _runToolCalls({
    required List<LlmToolCall> calls,
    required String assistantContent,
    required List<Map<String, Object?>> conversation,
    required _AgentSession session,
  }) async {
    for (final call in calls) {
      session.throwIfCancelled();

      final rejection = session.rejectionFor(call);
      if (rejection != null) {
        conversation.add(_toolMessage(call, {'error': rejection}));
        continue;
      }

      session.announce(call);
      final toolResult = await _executeTool(call, session.settings);

      final promptResult = _extractPromptResult(call, toolResult);
      if (promptResult != null) {
        return PromptAssistantReply(
          message: _replyMessage(assistantContent, promptResult),
          promptResult: promptResult,
        );
      }

      conversation.add(_toolMessage(call, toolResult));
      if (PromptAssistantTools.danbooruToolNames.contains(call.name)) {
        conversation.add({
          'role': 'system',
          'content':
              '已获得本轮标签查询结果。请结合这些结果继续完成当前回答；'
              '若用户要求提示词，可以调用 submit_prompt_result。',
        });
      }
    }
    return null;
  }

  List<Map<String, Object?>> _systemMessages(
    LlmAssistantSettings settings,
    String currentPositive,
    String currentNegative,
  ) => [
    {'role': 'system', 'content': settings.prompts.agentPrompt},
    {
      'role': 'system',
      'content': jsonEncode({
        'current_positive': currentPositive,
        'current_negative': currentNegative,
        'danbooru_tools_enabled': settings.danbooruToolsEnabled,
        'instruction': _instruction(settings.danbooruToolsEnabled),
      }),
    },
  ];

  String _instruction(bool danbooruEnabled) {
    const shared =
        '只有用户明确要求生成、整理、修改、优化、补全或应用提示词时才调用 submit_prompt_result 工具；'
        '该工具只控制全局正负面、多人正负面和人物位置，不得修改其他生成参数。不要在回复正文输出结构化 JSON。';
    final tools = danbooruEnabled
        ? '需要核对标签时可以使用 Danbooru 搜索或相关标签工具，并结合返回结果继续回答。'
        : 'Danbooru 标签查询工具已关闭，不要尝试调用或声称已查询标签。';
    return '普通问答、图片分析和创作讨论直接自然回复。$tools$shared';
  }

  PromptAssistantReply _plainReply(String content) {
    final promptResult = _promptResultFromContent(content);
    return PromptAssistantReply(
      message: promptResult == null
          ? content.trim()
          : _replyMessage('', promptResult),
      promptResult: promptResult,
    );
  }

  String _replyMessage(String assistantContent, PromptAssistantResult result) {
    final content = assistantContent.trim();
    if (content.isNotEmpty) return content;
    return result.notes.isNotEmpty ? result.notes : '提示词已写好。';
  }

  PromptAssistantResult? _extractPromptResult(
    LlmToolCall call,
    Object? toolResult,
  ) {
    if (call.name != PromptAssistantTools.submitPromptResult) return null;
    if (toolResult is! Map) return null;
    final resultJson = toolResult['prompt_result'];
    if (resultJson is! Map) return null;
    return PromptAssistantResult.fromJson(
      Map<String, Object?>.from(resultJson),
    );
  }

  Map<String, Object?> _assistantToolCallMessage(LlmChatResult result) => {
    'role': 'assistant',
    'content': result.content.isEmpty ? null : result.content,
    'tool_calls': result.toolCalls
        .map(
          (call) => {
            'id': call.id,
            'type': 'function',
            'function': {
              'name': call.name,
              'arguments': jsonEncode(call.arguments),
            },
          },
        )
        .toList(),
  };

  Map<String, Object?> _toolMessage(LlmToolCall call, Object? content) => {
    'role': 'tool',
    'tool_call_id': call.id,
    'name': call.name,
    'content': jsonEncode(content),
  };

  /// Some models wrap the result in prose instead of calling the tool; accept a
  /// trailing JSON object as long as it carries the required `positive` field.
  PromptAssistantResult? _promptResultFromContent(String content) {
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(content.substring(start, end + 1));
      if (decoded is! Map || !decoded.containsKey('positive')) return null;
      return PromptAssistantResult.fromJson(Map<String, Object?>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Object?>> _messagePayload(
    PromptChatMessage message,
  ) async {
    final imagePath = message.imagePath;
    if (imagePath == null || imagePath.trim().isEmpty) {
      return {'role': message.role.name, 'content': message.content};
    }
    final bytes = await File(imagePath).readAsBytes();
    final mime = switch (imagePath.split('.').last.toLowerCase()) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    return {
      'role': message.role.name,
      'content': [
        {
          'type': 'text',
          'text': message.content.trim().isEmpty
              ? '请分析这张图片。'
              : message.content.trim(),
        },
        {
          'type': 'image_url',
          'image_url': {'url': 'data:$mime;base64,${base64Encode(bytes)}'},
        },
      ],
    };
  }

  Future<Object?> _executeTool(
    LlmToolCall call,
    LlmAssistantSettings settings,
  ) async {
    if (call.name == PromptAssistantTools.submitPromptResult) {
      final promptResult = PromptAssistantResult.fromJson(call.arguments);
      if (promptResult.positive.trim().isEmpty) {
        return {'error': 'positive 不能为空'};
      }
      return {
        'accepted': true,
        'prompt_result': promptResult.toJson(),
        'instruction': '结果已交给应用处理。请用自然语言简短告知用户已准备好，可确认填入。',
      };
    }
    if (!settings.danbooruToolsEnabled) {
      return {'error': 'Danbooru 标签查询工具已关闭'};
    }
    final limit = _limit(call.arguments['limit']);
    if (call.name == 'danbooru_search') {
      final query = call.arguments['query']?.toString().trim() ?? '';
      if (query.isEmpty) return {'error': 'query 不能为空'};
      final values = await _danbooruService.search(
        query: query,
        showNsfw: settings.showNsfw,
        customBaseUrl: settings.danbooruBaseUrl,
        limit: limit,
      );
      return {'query': query, 'results': values.map(_tagJson).toList()};
    }
    if (call.name == 'danbooru_related') {
      final rawTags = call.arguments['tags'];
      final tags = rawTags is List
          ? rawTags
                .map((value) => value.toString().trim())
                .where((value) => value.isNotEmpty)
                .toList()
          : const <String>[];
      if (tags.isEmpty) return {'error': 'tags 不能为空'};
      final values = await _danbooruService.related(
        tags: tags,
        showNsfw: settings.showNsfw,
        customBaseUrl: settings.danbooruBaseUrl,
        limit: limit,
      );
      return {'tags': tags, 'results': values.map(_tagJson).toList()};
    }
    return {'error': '未知工具：${call.name}'};
  }

  int _limit(Object? value) {
    final parsed = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 12;
    return parsed.clamp(1, 30);
  }

  Map<String, Object?> _tagJson(DanbooruTag tag) => {
    'tag': tag.tag,
    'novelai_tag': tag.novelAiTag,
    'cn_name': tag.cnName,
    'category': tag.category,
    'count': tag.count,
    'score': tag.score,
    'wiki': tag.wiki,
    'sources': tag.sources,
  };
}

/// Tracks per-conversation tool state: duplicate calls and repeated tag lookups
/// are rejected at runtime so the schema descriptions can stay neutral.
class _AgentSession {
  _AgentSession({
    required this.settings,
    required this.cancelToken,
    required this.onStatus,
    required this.onNotice,
  }) : _danbooruAvailable = settings.danbooruToolsEnabled;

  final LlmAssistantSettings settings;
  final CancelToken? cancelToken;
  final void Function(String status)? onStatus;
  final void Function(String notice)? onNotice;

  final Set<String> _executedSignatures = {};
  bool _danbooruAvailable;

  List<Map<String, Object?>> get availableTools => [
    if (_danbooruAvailable) ...PromptAssistantTools.danbooru,
    ...PromptAssistantTools.prompt,
  ];

  void throwIfCancelled() {
    if (cancelToken?.isCancelled != true) return;
    throw DioException.requestCancelled(
      requestOptions: RequestOptions(),
      reason: '用户已中止请求',
    );
  }

  /// Returns an error message when the call must not run, or null to proceed.
  String? rejectionFor(LlmToolCall call) {
    final signature = '${call.name}:${jsonEncode(call.arguments)}';
    if (!_executedSignatures.add(signature)) {
      return '相同参数的工具调用已经执行过，请直接使用已有结果回答，不要重复调用。';
    }
    if (PromptAssistantTools.danbooruToolNames.contains(call.name) &&
        !_danbooruAvailable) {
      return '本次回复已经完成过标签查询。禁止继续搜索，请立即使用已有结果回答。';
    }
    return null;
  }

  void announce(LlmToolCall call) {
    if (PromptAssistantTools.danbooruToolNames.contains(call.name)) {
      _danbooruAvailable = false;
      final isSearch = call.name == 'danbooru_search';
      onNotice?.call(isSearch ? '提示词助手调用了标签搜索' : '提示词助手调用了相关标签查询');
      onStatus?.call(isSearch ? '正在搜索标签…' : '正在查询相关标签…');
      return;
    }
    if (call.name == PromptAssistantTools.submitPromptResult) {
      onNotice?.call('提示词助手正在整理提示词');
      onStatus?.call('正在整理提示词…');
    }
  }
}
