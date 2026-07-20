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

  static const _danbooruTools = <Map<String, Object?>>[
    {
      'type': 'function',
      'function': {
        'name': 'danbooru_search',
        'description': '根据自然语言、角色、作品、外观、动作或风格搜索真实 Danbooru 标签。',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string', 'description': '要检索的关键词或描述'},
            'limit': {'type': 'integer', 'description': '返回数量，建议 5 到 20'},
          },
          'required': ['query'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'danbooru_related',
        'description': '根据已经确认的 Danbooru 标签查询相关共现标签。',
        'parameters': {
          'type': 'object',
          'properties': {
            'tags': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': '已确认的 Danbooru 标签',
            },
            'limit': {'type': 'integer', 'description': '返回数量，建议 5 到 20'},
          },
          'required': ['tags'],
        },
      },
    },
  ];

  static const _promptTools = <Map<String, Object?>>[
    {
      'type': 'function',
      'function': {
        'name': 'submit_prompt_result',
        'description':
            '当用户明确要求生成、整理、修改、优化、补全或应用 NovelAI 提示词时，提交全局正负面提示词，以及可选的多人正负面提示词和位置。普通问答、图片分析和创作讨论不要调用。',
        'parameters': {
          'type': 'object',
          'properties': {
            'positive': {
              'type': 'string',
              'description': '英文半角逗号分隔的全局正向 NovelAI 标签',
            },
            'negative': {
              'type': 'string',
              'description': '英文半角逗号分隔的全局负向 NovelAI 标签',
            },
            'characters': {
              'type': 'array',
              'description': '多角色提示词；没有独立角色时传空数组，最多 6 个',
              'items': {
                'type': 'object',
                'properties': {
                  'prompt': {'type': 'string', 'description': '该角色的正向标签'},
                  'negative_prompt': {
                    'type': 'string',
                    'description': '该角色的负向标签',
                  },
                  'x': {
                    'type': 'number',
                    'description': '角色水平位置，0.1 左、0.5 中、0.9 右',
                  },
                  'y': {
                    'type': 'number',
                    'description': '角色垂直位置，0.1 上、0.5 中、0.9 下',
                  },
                  'enabled': {'type': 'boolean', 'description': '是否启用该角色'},
                },
                'required': ['prompt', 'negative_prompt', 'x', 'y', 'enabled'],
              },
            },
            'notes': {'type': 'string', 'description': '用简体中文简要说明已准备的提示词'},
          },
          'required': ['positive', 'negative', 'characters', 'notes'],
        },
      },
    },
  ];

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
    final apiKey =
        await _credentialStore.read(AppConstants.llmCredentialKey) ?? '';
    final executedToolCalls = <String>{};
    var danbooruCallCount = 0;
    var danbooruToolsAvailable = settings.danbooruToolsEnabled;
    final conversation = <Map<String, Object?>>[
      {'role': 'system', 'content': settings.prompts.agentPrompt},
      {
        'role': 'system',
        'content': jsonEncode({
          'current_positive': currentPositive,
          'current_negative': currentNegative,
          'danbooru_tools_enabled': settings.danbooruToolsEnabled,
          'instruction': settings.danbooruToolsEnabled
              ? '普通问答、图片分析和创作讨论直接自然回复。需要核对标签时可以使用 Danbooru 搜索或相关标签工具，并结合返回结果继续回答。只有用户明确要求生成、整理、修改、优化、补全或应用提示词时才调用 submit_prompt_result 工具；该工具只控制全局正负面、多人正负面和人物位置，不得修改其他生成参数。不要在回复正文输出结构化 JSON。'
              : '普通问答、图片分析和创作讨论直接自然回复。Danbooru 标签查询工具已关闭，不要尝试调用或声称已查询标签。只有用户明确要求生成、整理、修改、优化、补全或应用提示词时才调用 submit_prompt_result 工具；该工具只控制全局正负面、多人正负面和人物位置，不得修改其他生成参数。不要在回复正文输出结构化 JSON。',
        }),
      },
      ...await Future.wait(messages.map(_messagePayload)),
    ];

    for (var round = 0; round < 6; round++) {
      onStatus?.call(round == 0 ? '正在请求模型…' : '正在等待模型整理结果…');
      final tools = <Map<String, Object?>>[
        if (danbooruToolsAvailable) ..._danbooruTools,
        ..._promptTools,
      ];
      if (cancelToken?.isCancelled == true) {
        throw DioException.requestCancelled(
          requestOptions: RequestOptions(),
          reason: '用户已中止请求',
        );
      }
      final result = await _llmService.completeWithTools(
        baseUrl: settings.baseUrl,
        apiKey: apiKey,
        model: settings.model,
        messages: conversation,
        tools: tools,
        cancelToken: cancelToken,
      );
      if (result.reasoningContent.isNotEmpty) {
        onStatus?.call('模型正在思考…');
      }
      if (result.toolCalls.isEmpty) {
        final promptResult = _promptResultFromContent(result.content);
        return PromptAssistantReply(
          message: promptResult == null
              ? result.content.trim()
              : promptResult.notes.isNotEmpty
              ? promptResult.notes
              : '提示词已写好。',
          promptResult: promptResult,
        );
      }
      conversation.add({
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
      });
      for (final call in result.toolCalls) {
        if (cancelToken?.isCancelled == true) {
          throw DioException.requestCancelled(
            requestOptions: RequestOptions(),
            reason: '用户已中止请求',
          );
        }
        final signature = '${call.name}:${jsonEncode(call.arguments)}';
        if (!executedToolCalls.add(signature)) {
          conversation.add({
            'role': 'tool',
            'tool_call_id': call.id,
            'name': call.name,
            'content': jsonEncode({
              'error': '相同参数的工具调用已经执行过，请直接使用已有结果回答，不要重复调用。',
            }),
          });
          continue;
        }
        if (call.name == 'danbooru_search' || call.name == 'danbooru_related') {
          if (danbooruCallCount >= 1) {
            conversation.add({
              'role': 'tool',
              'tool_call_id': call.id,
              'name': call.name,
              'content': jsonEncode({
                'error': '本次回复已经完成过标签查询。禁止继续搜索，请立即使用已有结果回答。',
              }),
            });
            continue;
          }
          danbooruCallCount = 1;
          danbooruToolsAvailable = false;
          final notice = call.name == 'danbooru_search'
              ? '提示词助手调用了标签搜索'
              : '提示词助手调用了相关标签查询';
          onNotice?.call(notice);
          onStatus?.call(
            call.name == 'danbooru_search' ? '正在搜索标签…' : '正在查询相关标签…',
          );
        }
        if (call.name == 'submit_prompt_result') {
          onNotice?.call('提示词助手正在整理提示词');
          onStatus?.call('正在整理提示词…');
        }
        final toolResult = await _executeTool(call, settings);
        if (call.name == 'submit_prompt_result' && toolResult is Map) {
          final resultJson = toolResult['prompt_result'];
          if (resultJson is Map) {
            final promptResult = PromptAssistantResult.fromJson(
              Map<String, Object?>.from(resultJson),
            );
            return PromptAssistantReply(
              message: result.content.trim().isNotEmpty
                  ? result.content.trim()
                  : promptResult.notes.isNotEmpty
                  ? promptResult.notes
                  : '提示词已写好。',
              promptResult: promptResult,
            );
          }
        }
        conversation.add({
          'role': 'tool',
          'tool_call_id': call.id,
          'name': call.name,
          'content': jsonEncode(toolResult),
        });
        if (call.name == 'danbooru_search' || call.name == 'danbooru_related') {
          conversation.add({
            'role': 'system',
            'content':
                '已获得本轮标签查询结果。请结合这些结果继续完成当前回答；若用户要求提示词，可以调用 submit_prompt_result。',
          });
        }
      }
    }
    return const PromptAssistantReply(
      message: '模型未能完成本次工具流程，请关闭标签查询工具后重试，或换用支持 OpenAI Tool Calling 的模型。',
    );
  }

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
    final extension = imagePath.split('.').last.toLowerCase();
    final mime = switch (extension) {
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
    if (call.name == 'submit_prompt_result') {
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
    if (!settings.danbooruToolsEnabled &&
        (call.name == 'danbooru_search' || call.name == 'danbooru_related')) {
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
