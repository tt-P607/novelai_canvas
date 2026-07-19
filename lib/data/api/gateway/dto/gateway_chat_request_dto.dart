import 'dart:convert';

import '../../common/api_request_builder.dart';

class GatewayChatMessageDto {
  const GatewayChatMessageDto({required this.role, required this.content});
  final String role;
  final String content;
  Map<String, Object?> toJson() => {'role': role, 'content': content};
}

class GatewayChatRequestDto {
  const GatewayChatRequestDto({
    required this.model,
    required this.messages,
    this.stream = false,
    this.scale = 5,
    this.cfgRescale = 0,
    this.width = 1024,
    this.height = 1024,
    this.sampler = 'k_euler_ancestral',
    this.noiseSchedule = 'karras',
    this.responseFormat = 'url',
  });
  final String model;
  final List<GatewayChatMessageDto> messages;
  final bool stream;
  final double scale;
  final double cfgRescale;
  final int width;
  final int height;
  final String sampler;
  final String noiseSchedule;
  final String responseFormat;
}

class GatewayChatRequestBuilder
    implements ApiRequestBuilder<GatewayChatRequestDto> {
  const GatewayChatRequestBuilder();
  @override
  int get templateVersion => 1;
  @override
  JsonMap build(
    GatewayChatRequestDto request, {
    List<JsonMap> patches = const [],
  }) => applyRequestPatches({
    'model': request.model,
    'messages': request.messages.map((message) => message.toJson()).toList(),
    'stream': request.stream,
    'scale': request.scale,
    'cfg_rescale': request.cfgRescale,
    'width': request.width,
    'height': request.height,
    'sampler': request.sampler,
    'noise_schedule': request.noiseSchedule,
    'response_format': request.responseFormat,
  }, patches);
}

class GatewayChatStreamEventDto {
  const GatewayChatStreamEventDto({
    required this.content,
    required this.finished,
  });
  final String? content;
  final bool finished;
}

GatewayChatStreamEventDto? parseGatewayChatSseData(String line) {
  if (!line.startsWith('data:')) return null;
  final payload = line.substring(5).trim();
  if (payload.isEmpty) return null;
  if (payload == '[DONE]') {
    return const GatewayChatStreamEventDto(content: null, finished: true);
  }
  final json = Map<String, Object?>.from(jsonDecode(payload) as Map);
  final choices = json['choices'] as List?;
  if (choices == null || choices.isEmpty || choices.first is! Map) return null;
  final choice = Map<String, Object?>.from(choices.first as Map);
  final delta = choice['delta'] is Map
      ? Map<String, Object?>.from(choice['delta']! as Map)
      : const <String, Object?>{};
  return GatewayChatStreamEventDto(
    content: delta['content']?.toString(),
    finished: choice['finish_reason'] != null,
  );
}
