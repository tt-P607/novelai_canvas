/// OpenAI tool schemas offered to the prompt assistant agent.
///
/// Each tool carries its own `guidance` text so the main system prompt can
/// stay tool-agnostic: when a tool is toggled off it disappears entirely from
/// the context, including its description. Loop protection is enforced at
/// runtime by the repository, not by defensive wording in the schema.
abstract final class PromptAssistantTools {
  static const danbooru = <PromptAssistantTool>[
    PromptAssistantTool(
      schema: {
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
      guidance:
          '当专有角色、作品、服装变体、生僻动作或标签拼写需要确认时，'
          '使用 `danbooru_search` 查询真实标签，不要捏造专有标签。',
    ),
    PromptAssistantTool(
      schema: {
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
      guidance: '已有确定标签后，可用 `danbooru_related` 查询高频共现标签以丰富细节。',
    ),
  ];

  static const prompt = <PromptAssistantTool>[
    PromptAssistantTool(
      schema: {
        'type': 'function',
        'function': {
          'name': 'submit_prompt_result',
          'description':
              '当用户明确要求生成、整理、修改、优化、补全或应用 NovelAI 提示词时，'
              '提交全局正负面提示词，以及可选的多人正负面提示词和位置。'
              '普通问答、图片分析和创作讨论不要调用。',
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
                  'required': [
                    'prompt',
                    'negative_prompt',
                    'x',
                    'y',
                    'enabled',
                  ],
                },
              },
              'notes': {'type': 'string', 'description': '用简体中文简要说明已准备的提示词'},
            },
            'required': ['positive', 'negative', 'characters', 'notes'],
          },
        },
      },
      guidance:
          '用户明确要求生成、整理、修改、优化、补全或应用提示词时调用 '
          '`submit_prompt_result` 提交结果。该工具只控制全局正负面、多人正负面和人物位置，'
          '不得修改其他生成参数。不要在回复正文输出结构化 JSON。',
    ),
  ];

  static const danbooruToolNames = {'danbooru_search', 'danbooru_related'};
  static const submitPromptResult = 'submit_prompt_result';
}

/// A tool exposed to the LLM plus its self-contained guidance text.
///
/// `guidance` is injected into the system prompt dynamically based on which
/// tools are currently enabled — decoupling tool descriptions from the main
/// agent prompt so toggling a tool removes its context entirely.
class PromptAssistantTool {
  const PromptAssistantTool({required this.schema, required this.guidance});

  /// The OpenAI function-calling JSON schema sent to the model.
  final Map<String, Object?> schema;

  /// Chinese guidance text merged into the system prompt when this tool is
  /// available. Kept factual; runtime guards live in the repository.
  final String guidance;
}
