/// OpenAI tool schemas offered to the prompt assistant agent.
///
/// Descriptions stay purely factual: loop protection is enforced at runtime by
/// the repository, not by defensive wording in the schema.
abstract final class PromptAssistantTools {
  static const danbooru = <Map<String, Object?>>[
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

  static const prompt = <Map<String, Object?>>[
    {
      'type': 'function',
      'function': {
        'name': 'submit_prompt_result',
        'description':
            '当用户明确要求生成、整理、修改、优化、补全或应用 NovelAI 提示词时，提交全局正负面提示词，'
            '以及可选的多人正负面提示词和位置。普通问答、图片分析和创作讨论不要调用。',
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

  static const danbooruToolNames = {'danbooru_search', 'danbooru_related'};
  static const submitPromptResult = 'submit_prompt_result';
}
