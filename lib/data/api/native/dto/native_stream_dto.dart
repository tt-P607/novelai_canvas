import 'dart:convert';

import '../../common/api_request_builder.dart';

class NativeStreamRequestDto {
  const NativeStreamRequestDto(this.payload);

  /// 完整的 NovelAI 生成请求，可对应 generate、img2img 或 infill。
  final JsonMap payload;
}

class NativeStreamEventDto {
  const NativeStreamEventDto({
    required this.eventType,
    required this.sampleIndex,
    required this.stepIndex,
    required this.generationId,
    required this.sigma,
    required this.image,
  });

  final String eventType;
  final int sampleIndex;
  final int stepIndex;
  final int generationId;
  final double sigma;
  final String image;

  bool get isFinal => eventType == 'final';

  factory NativeStreamEventDto.fromJson(Map<String, Object?> json) =>
      NativeStreamEventDto(
        eventType: json['event_type']?.toString() ?? 'intermediate',
        sampleIndex: (json['samp_ix'] as num?)?.toInt() ?? 0,
        stepIndex: (json['step_ix'] as num?)?.toInt() ?? 0,
        generationId: (json['gen_id'] as num?)?.toInt() ?? 0,
        sigma: (json['sigma'] as num?)?.toDouble() ?? 0,
        image: json['image']?.toString() ?? '',
      );
}

class NativeStreamRequestBuilder
    implements ApiRequestBuilder<NativeStreamRequestDto> {
  const NativeStreamRequestBuilder();

  @override
  int get templateVersion => 1;

  @override
  JsonMap build(
    NativeStreamRequestDto request, {
    List<JsonMap> patches = const [],
  }) {
    final base = Map<String, Object?>.from(request.payload);
    final rawParameters = base['parameters'];
    if (rawParameters is! Map) {
      throw const FormatException('流式生成请求缺少 parameters。');
    }
    final parameters = Map<String, Object?>.from(rawParameters)
      ..['stream'] = 'sse';
    base['parameters'] = parameters;
    return applyRequestPatches(base, patches);
  }
}

NativeStreamEventDto? parseNativeSseData(String line) {
  if (!line.startsWith('data:')) return null;
  final payload = line.substring(5).trim();
  if (payload.isEmpty || payload == '[DONE]') return null;
  return NativeStreamEventDto.fromJson(
    Map<String, Object?>.from(jsonDecode(payload) as Map),
  );
}
