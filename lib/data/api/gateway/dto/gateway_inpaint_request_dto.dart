import '../../common/api_request_builder.dart';

/// Gateway inpainting request per the new-api OpenAI Images contract.
///
/// OpenAI-standard fields stay at the top level; NovelAI-specific parameters
/// live in `params` (see `docs/OpenAI兼容接口对接文档.md`), and
/// `response_format` only supports `b64_json`. Mask semantics are the OpenAI
/// convention (transparent area repainted); the gateway converts them.
class GatewayInpaintRequestDto {
  const GatewayInpaintRequestDto({
    required this.model,
    required this.prompt,
    required this.image,
    required this.mask,
    this.strength = 1,
    this.noise = 0,
    this.size,
    this.width,
    this.height,
    this.negativePrompt,
    this.steps = 28,
    this.scale = 5,
    this.cfgRescale = 0,
    this.sampler = 'k_euler_ancestral',
    this.noiseSchedule = 'karras',
    this.seed,
    this.quality = true,
    this.ucPreset,
    this.responseFormat = 'b64_json',
  });

  final String model;
  final String prompt;
  final String image;
  final String mask;
  final double strength;
  final double noise;
  final String? size;
  final int? width;
  final int? height;
  final String? negativePrompt;
  final int steps;
  final double scale;
  final double cfgRescale;
  final String sampler;
  final String noiseSchedule;
  final int? seed;
  final bool quality;
  final String? ucPreset;
  final String responseFormat;
}

class GatewayInpaintRequestBuilder
    implements ApiRequestBuilder<GatewayInpaintRequestDto> {
  const GatewayInpaintRequestBuilder();

  @override
  int get templateVersion => 1;

  @override
  JsonMap build(
    GatewayInpaintRequestDto request, {
    List<JsonMap> patches = const [],
  }) {
    final params = <String, Object?>{
      'steps': request.steps,
      'scale': request.scale,
      'cfg_rescale': request.cfgRescale,
      'sampler': request.sampler,
      'noise_schedule': request.noiseSchedule,
      'quality': request.quality,
      if (request.ucPreset != null) 'uc_preset': request.ucPreset,
      if (request.negativePrompt != null && request.negativePrompt!.isNotEmpty)
        'negative_prompt': request.negativePrompt,
    };
    return applyRequestPatches({
      'model': request.model,
      'prompt': request.prompt,
      'image': request.image,
      'mask': request.mask,
      'strength': request.strength,
      'noise': request.noise,
      if (request.size != null) 'size': request.size,
      if (request.width != null) 'width': request.width,
      if (request.height != null) 'height': request.height,
      if (request.seed != null) 'seed': request.seed,
      'response_format': request.responseFormat,
      'params': params,
    }, patches);
  }
}
