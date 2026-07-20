import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_canvas/data/api/danbooru/danbooru_service.dart';
import 'package:novelai_canvas/data/api/llm/llm_chat_service.dart';

void main() {
  test('LLM 获取 OpenAI 兼容模型列表并排序去重', () async {
    final adapter = _RoutingAdapter((options) {
      expect(options.method, 'GET');
      expect(options.path, 'https://llm.example.com/v1/models');
      expect(options.headers['Authorization'], 'Bearer secret');
      return {
        'data': [
          {'id': 'z-model'},
          {'id': 'a-model'},
          {'id': 'a-model'},
        ],
      };
    });
    final service = LlmChatService(Dio()..httpClientAdapter = adapter);

    final models = await service.listModels(
      baseUrl: 'https://llm.example.com',
      apiKey: 'secret',
    );

    expect(models, ['a-model', 'z-model']);
  });

  test('LLM Chat 使用独立 OpenAI 兼容请求并解析文本', () async {
    final adapter = _RoutingAdapter((options) {
      expect(options.path, 'https://llm.example.com/v1/chat/completions');
      expect(options.headers['Authorization'], 'Bearer secret');
      final body = options.data as Map;
      expect(body['model'], 'test-model');
      expect(body['stream'], false);
      return {
        'choices': [
          {
            'message': {'content': 'assistant result'},
          },
        ],
      };
    });
    final dio = Dio()..httpClientAdapter = adapter;

    final result = await LlmChatService(dio).complete(
      baseUrl: 'https://llm.example.com',
      apiKey: 'secret',
      model: 'test-model',
      messages: const [
        {'role': 'user', 'content': 'hello'},
      ],
    );

    expect(result, 'assistant result');
  });

  test('Danbooru search 和 related 解析真实标签元数据', () async {
    final adapter = _RoutingAdapter((options) {
      if (options.path.endsWith('/api/search')) {
        return {
          'results': [
            {
              'tag': 'silver_hair',
              'cn_name': '银发',
              'category': 'General',
              'count': 123,
              'final_score': 0.9,
              'wiki': 'hair color',
            },
          ],
        };
      }
      return [
        {
          'tag': 'long_hair',
          'post_count': 456,
          'cooc_score': 0.8,
          'sources': ['silver_hair'],
        },
      ];
    });
    final service = DanbooruService(Dio()..httpClientAdapter = adapter);

    final searched = await service.search(
      query: '银发少女',
      showNsfw: false,
      customBaseUrl: 'https://danbooru.example.com',
    );
    final related = await service.related(
      tags: ['silver_hair'],
      showNsfw: false,
      customBaseUrl: 'https://danbooru.example.com',
    );

    expect(searched.single.novelAiTag, 'silver hair');
    expect(searched.single.cnName, '银发');
    expect(related.single.sources, ['silver_hair']);
  });
}

class _RoutingAdapter implements HttpClientAdapter {
  _RoutingAdapter(this.handler);

  final Object? Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(handler(options)),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}
