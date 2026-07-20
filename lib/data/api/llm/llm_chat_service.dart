import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';

class LlmToolCall {
  const LlmToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final Map<String, Object?> arguments;
}

class LlmChatResult {
  const LlmChatResult({
    required this.content,
    this.reasoningContent = '',
    this.toolCalls = const [],
  });

  final String content;
  final String reasoningContent;
  final List<LlmToolCall> toolCalls;
}

class LlmChatService {
  LlmChatService(this._dio);

  final Dio _dio;

  Future<String> complete({
    required String baseUrl,
    required String apiKey,
    required String model,
    required List<Map<String, Object?>> messages,
  }) async => (await completeWithTools(
    baseUrl: baseUrl,
    apiKey: apiKey,
    model: model,
    messages: messages,
  )).content;

  Future<List<String>> listModels({
    required String baseUrl,
    required String apiKey,
    CancelToken? cancelToken,
  }) async {
    if (baseUrl.trim().isEmpty) {
      throw const ConfigurationException('请先配置 LLM Base URL。');
    }
    if (apiKey.trim().isEmpty) {
      throw const ConfigurationException('请先配置 LLM API Key。');
    }
    final normalized = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    try {
      final response = await _dio.get<Object?>(
        '$normalized/v1/models',
        cancelToken: cancelToken,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${apiKey.trim()}',
            'Accept': 'application/json',
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 45),
        ),
      );
      final data = response.data;
      final values = data is Map ? data['data'] : null;
      if (values is! List) {
        throw const DataParsingException('模型列表响应缺少 data。');
      }
      final models =
          values
              .whereType<Map>()
              .map((value) => value['id']?.toString().trim() ?? '')
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      return models;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      throw _networkException(error, '获取模型列表失败，请检查服务配置。');
    }
  }

  Future<LlmChatResult> completeWithTools({
    required String baseUrl,
    required String apiKey,
    required String model,
    required List<Map<String, Object?>> messages,
    List<Map<String, Object?>> tools = const [],
    CancelToken? cancelToken,
  }) async {
    if (baseUrl.trim().isEmpty) {
      throw const ConfigurationException('请先配置 LLM Base URL。');
    }
    if (apiKey.trim().isEmpty) {
      throw const ConfigurationException('请先配置 LLM API Key。');
    }
    if (model.trim().isEmpty) {
      throw const ConfigurationException('请先配置 LLM 模型。');
    }

    final normalized = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    try {
      final data = <String, Object?>{
        'model': model.trim(),
        'messages': messages,
        'stream': false,
        if (tools.isNotEmpty) ...{'tools': tools, 'tool_choice': 'auto'},
      };
      final response = await _dio.post<Object?>(
        '$normalized/v1/chat/completions',
        data: data,
        cancelToken: cancelToken,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${apiKey.trim()}',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      return _result(response.data);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      throw _networkException(error, 'LLM 请求失败，请检查服务配置。');
    }
  }

  NetworkException _networkException(DioException error, String fallback) {
    final data = error.response?.data;
    final message = data is Map
        ? (data['error'] is Map
              ? (data['error'] as Map)['message']
              : data['message'])
        : null;
    return NetworkException(
      message?.toString() ?? error.message ?? fallback,
      statusCode: error.response?.statusCode,
      responseBody: data,
      cause: error,
    );
  }

  LlmChatResult _result(Object? data) {
    if (data is! Map) {
      throw const DataParsingException('LLM 响应不是 JSON 对象。');
    }
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      throw const DataParsingException('LLM 响应缺少 choices。');
    }
    final message = (choices.first as Map)['message'];
    if (message is! Map) {
      throw const DataParsingException('LLM 响应缺少 message。');
    }
    final toolCalls = _toolCalls(message['tool_calls']);
    final content = _content(message['content']);
    final reasoningContent = _reasoningContent(message);
    if (content.isEmpty && reasoningContent.isEmpty && toolCalls.isEmpty) {
      final choice = choices.first as Map;
      final finishReason = choice['finish_reason']?.toString() ?? '';
      final nativeFinishReason =
          choice['native_finish_reason']?.toString() ?? '';
      if (finishReason == 'prohibited_content' ||
          nativeFinishReason == 'prohibited_content') {
        throw const NetworkException('模型因内容安全策略未返回结果，请调整描述后重试。');
      }
      throw const DataParsingException('模型没有返回可用内容，请重试或更换模型。');
    }
    return LlmChatResult(
      content: content,
      reasoningContent: reasoningContent,
      toolCalls: toolCalls,
    );
  }

  String _content(Object? content) {
    if (content is String) return content.trim();
    if (content is List) {
      final buffer = StringBuffer();
      for (final part in content.whereType<Map>()) {
        if (part['type'] == 'text' && part['text'] != null) {
          buffer.write(part['text']);
        }
      }
      return buffer.toString().trim();
    }
    return '';
  }

  String _reasoningContent(Map message) {
    for (final key in const [
      'reasoning_content',
      'reasoning',
      'thinking',
      'thought',
    ]) {
      final value = _content(message[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  List<LlmToolCall> _toolCalls(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((raw) {
          final function = raw['function'];
          if (function is! Map) return null;
          final rawArguments = function['arguments']?.toString() ?? '{}';
          Map<String, Object?> arguments;
          try {
            final decoded = jsonDecode(rawArguments);
            arguments = decoded is Map
                ? Map<String, Object?>.from(decoded)
                : const {};
          } catch (_) {
            arguments = const {};
          }
          final name = function['name']?.toString() ?? '';
          if (name.isEmpty) return null;
          return LlmToolCall(
            id: raw['id']?.toString() ?? name,
            name: name,
            arguments: arguments,
          );
        })
        .whereType<LlmToolCall>()
        .toList();
  }
}
