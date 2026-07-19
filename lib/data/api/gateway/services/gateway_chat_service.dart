import 'dart:async';
import 'dart:convert';

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
    } catch (error) {
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
        options: Options(responseType: ResponseType.stream),
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
    } catch (error) {
      throw NetworkErrorMapper.map(error);
    }
  }
}
