import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';

class LlmChatService {
  LlmChatService(this._dio);

  final Dio _dio;

  Future<String> complete({
    required String baseUrl,
    required String apiKey,
    required String model,
    required List<Map<String, Object?>> messages,
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
      final response = await _dio.post<Object?>(
        '$normalized/v1/chat/completions',
        data: {'model': model.trim(), 'messages': messages, 'stream': false},
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
      return _content(response.data);
    } on DioException catch (error) {
      final data = error.response?.data;
      final message = data is Map
          ? (data['error'] is Map
                ? (data['error'] as Map)['message']
                : data['message'])
          : null;
      throw NetworkException(
        message?.toString() ?? error.message ?? 'LLM 请求失败，请检查服务配置。',
        statusCode: error.response?.statusCode,
        responseBody: data,
        cause: error,
      );
    }
  }

  String _content(Object? data) {
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
    final content = message['content'];
    if (content is String && content.trim().isNotEmpty) return content.trim();
    if (content is List) {
      final buffer = StringBuffer();
      for (final part in content.whereType<Map>()) {
        if (part['type'] == 'text' && part['text'] != null) {
          buffer.write(part['text']);
        }
      }
      if (buffer.isNotEmpty) return buffer.toString().trim();
    }
    throw DataParsingException('LLM 响应没有可用文本：${jsonEncode(data)}');
  }
}
