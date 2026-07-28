import '../../common/api_request_builder.dart';

class GatewayTextToImageRequestDto {
  const GatewayTextToImageRequestDto({
    required this.model,
    required this.prompt,
    required this.width,
    required this.height,
    required this.steps,
    required this.scale,
    required this.cfgRescale,
    required this.sampler,
    required this.noiseSchedule,
    required this.seed,
    required this.negativePrompt,
    required this.quality,
    required this.ucPreset,
    this.characters = const [],
    this.responseFormat = 'b64_json',
  });

  final String model;
  final String prompt;
  final int width;
  final int height;
  final int steps;
  final double scale;
  final double cfgRescale;
  final String sampler;
  final String noiseSchedule;
  final int seed;
  final String negativePrompt;
  final bool quality;
  final int ucPreset;
  final List<JsonMap> characters;
  final String responseFormat;
}

class GatewayTextToImageRequestBuilder
    implements ApiRequestBuilder<GatewayTextToImageRequestDto> {
  const GatewayTextToImageRequestBuilder();

  @override
  int get templateVersion => 1;

  @override
  JsonMap build(
    GatewayTextToImageRequestDto request, {
    List<JsonMap> patches = const [],
  }) => applyRequestPatches({
    'model': request.model,
    'prompt': request.prompt,
    'width': request.width,
    'height': request.height,
    'steps': request.steps,
    'scale': request.scale,
    'cfg_rescale': request.cfgRescale,
    'sampler': request.sampler,
    'noise_schedule': request.noiseSchedule,
    'seed': request.seed,
    'negative_prompt': request.negativePrompt,
    'qualityToggle': request.quality,
    'ucPreset': request.ucPreset,
    if (request.characters.isNotEmpty) 'characters': request.characters,
    'response_format': request.responseFormat,
  }, patches);
}
