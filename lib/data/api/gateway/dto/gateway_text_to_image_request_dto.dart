import '../../common/api_request_builder.dart';

/// Gateway text-to-image request per the new-api OpenAI Images contract.
///
/// NovelAI-specific parameters live in the `params` object (see
/// `docs/OpenAI兼容接口对接文档.md`), and `response_format` only supports
/// `b64_json`. Multi-character prompts and Vibe references are carried inside
/// `params` exactly as the gateway maps them to the native request.
class GatewayTextToImageRequestDto {
  const GatewayTextToImageRequestDto({
    required this.model,
    required this.prompt,
    this.n = 1,
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
    this.sm = false,
    this.smDyn = false,
    this.characters = const [],
    this.encodedReferences = const [],
    this.referenceStrengths = const [],
    this.informationExtractedValues = const [],
    this.responseFormat = 'b64_json',
  });

  final String model;
  final String prompt;
  final int n;
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
  final bool sm;
  final bool smDyn;
  final List<Map<String, Object?>> characters;
  final List<String> encodedReferences;
  final List<double> referenceStrengths;
  final List<double> informationExtractedValues;
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
  }) {
    final params = <String, Object?>{
      'steps': request.steps,
      'scale': request.scale,
      'cfg_rescale': request.cfgRescale,
      'sampler': request.sampler,
      'noise_schedule': request.noiseSchedule,
      'quality': request.quality,
      if (request.ucPreset != null) 'uc_preset': request.ucPreset,
      'sm': request.sm,
      'sm_dyn': request.smDyn,
      if (request.negativePrompt != null && request.negativePrompt!.isNotEmpty)
        'negative_prompt': request.negativePrompt,
      if (request.characters.isNotEmpty) 'characters': request.characters,
      if (request.encodedReferences.isNotEmpty)
        'reference_image_multiple': request.encodedReferences,
      if (request.referenceStrengths.isNotEmpty)
        'reference_strength_multiple': request.referenceStrengths,
      if (request.informationExtractedValues.isNotEmpty)
        'reference_information_extracted_multiple':
            request.informationExtractedValues,
    };
    return applyRequestPatches({
      'model': request.model,
      'prompt': request.prompt,
      'n': request.n,
      if (request.size != null) 'size': request.size,
      if (request.width != null) 'width': request.width,
      if (request.height != null) 'height': request.height,
      if (request.seed != null) 'seed': request.seed,
      'response_format': request.responseFormat,
      'params': params,
    }, patches);
  }
}
