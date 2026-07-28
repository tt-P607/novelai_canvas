import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';

import '../../../../core/network/image_response_decoder.dart';
import '../../../../core/network/json_patch_applier.dart';
import '../../../../core/network/network_error_mapper.dart';
import '../../../../domain/entities/image_generation_result.dart';
import '../dto/gateway_chat_request_dto.dart';
import '../gateway_api_service.dart';

class GatewayChatService extends GatewayApiService {
  GatewayChatService(super.client, {GatewayChatRequestBuilder? builder})
    : builder = builder ?? const GatewayChatRequestBuilder();

  final GatewayChatRequestBuilder builder;

  Future<ImageGenerationResult> complete(
    GatewayChatRequestDto request, {
    List<JsonMap> patches = const [],
  }) async {
    try {
      final response = await client.post<Object?>(
        '/v1/chat/completions',
        data: builder.build(request, patches: patches),
      );
      final json = Map<String, Object?>.from(response.data! as Map);
      final choices = json['choices'] as List? ?? const [];
      if (choices.isEmpty || choices.first is! Map) {
        throw const FormatException('Chat 响应缺少 choices。');
      }
      final choice = Map<String, Object?>.from(choices.first as Map);
      final message = Map<String, Object?>.from(choice['message']! as Map);
      final created = (json['created'] as num?)?.toInt();
      return ImageGenerationResult(
        images: [
          ImageResponseDecoder.decodeChatMarkdown(
            message['content']?.toString() ?? '',
          ),
        ],
        createdAt: created == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(created * 1000),
        requestId: json['id']?.toString(),
      );
    } on DioException catch (error) {
      log(
        '[GatewayChatService.complete] DioException '
        'type=${error.type} statusCode=${error.response?.statusCode} '
        'uri=${error.requestOptions.uri} '
        'response=${_truncateForLog(error.response?.data)}',
      );
      throw NetworkErrorMapper.map(error);
    } catch (error) {
      log('[GatewayChatService.complete] non-Dio error: $error');
      throw NetworkErrorMapper.map(error);
    }
  }

  Stream<GatewayChatStreamEventDto> stream(
    GatewayChatRequestDto request, {
    List<JsonMap> patches = const [],
  }) async* {
    try {
      final json = builder.build(request, patches: patches)..['stream'] = true;
      final response = await client.post<ResponseBody>(
        '/v1/chat/completions',
        data: json,
        // OpenAI 兼容代理（如 newapi）依据该头决定是否透传 SSE，
        // 缺失时会把流式响应缓冲为普通 JSON，破坏渐进式预览。
        options: Options(
          responseType: ResponseType.stream,
          headers: const {'Accept': 'text/event-stream'},
        ),
      );
      final body = response.data;
      if (body == null) return;
      final lines = body.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        final event = parseGatewayChatSseData(line);
        if (event != null) yield event;
      }
    } on DioException catch (error) {
      // For streaming requests the error body is a ResponseBody whose bytes
      // must be drained to read the real newapi error message.
      final extracted = await _drainStreamBody(error.response?.data);
      log(
        '[GatewayChatService.stream] DioException '
        'type=${error.type} statusCode=${error.response?.statusCode} '
        'uri=${error.requestOptions.uri} '
        'response=$extracted',
      );
      throw NetworkErrorMapper.map(error);
    } catch (error) {
      log('[GatewayChatService.stream] non-Dio error: $error');
      throw NetworkErrorMapper.map(error);
    }
  }

  /// Reads up to 2 KB from a streamed [ResponseBody] so the real error text
  /// can be surfaced in logs instead of the opaque `<ResponseBody>` type name.
  static Future<String?> _drainStreamBody(Object? data) async {
    if (data is! ResponseBody) return null;
    try {
      final bytes = <int>[];
      await for (final chunk in data.stream) {
        bytes.addAll(chunk);
        if (bytes.length >= 2048) break;
      }
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  static String _truncateForLog(Object? value) {
    if (value == null) return '<null>';
    String text;
    if (value is String) {
      text = value;
    } else if (value is List<int>) {
      text = utf8.decode(value, allowMalformed: true);
    } else {
      try {
        text = jsonEncode(value);
      } catch (_) {
        text = '<${value.runtimeType}>';
      }
    }
    if (text.length <= 500) return text;
    return '${text.substring(0, 500)}…';
  }
}
