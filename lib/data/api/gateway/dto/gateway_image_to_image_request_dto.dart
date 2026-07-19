import '../../common/api_request_builder.dart';

class GatewayImageToImageRequestDto {
  const GatewayImageToImageRequestDto({
    required this.model,
    required this.prompt,
    required this.image,
    this.strength = 1,
    this.addOriginalImage = false,
    this.size,
    this.width,
    this.height,
    this.scale = 5,
    this.cfgRescale = 0,
    this.sampler = 'k_euler_ancestral',
    this.noiseSchedule = 'karras',
    this.seed,
    this.negativePrompt,
    this.quality = true,
    this.ucPreset = 1,
    this.responseFormat = 'url',
    this.imageFormat,
  });
  final String model;
  final String prompt;
  final String image;
  final double strength;
  final bool addOriginalImage;
  final String? size;
  final int? width;
  final int? height;
  final double scale;
  final double cfgRescale;
  final String sampler;
  final String noiseSchedule;
  final int? seed;
  final String? negativePrompt;
  final bool quality;
  final int ucPreset;
  final String responseFormat;
  final String? imageFormat;
}

class GatewayImageToImageRequestBuilder
    implements ApiRequestBuilder<GatewayImageToImageRequestDto> {
  const GatewayImageToImageRequestBuilder();
  @override
  int get templateVersion => 1;
  @override
  JsonMap build(
    GatewayImageToImageRequestDto request, {
    List<JsonMap> patches = const [],
  }) => applyRequestPatches({
    'model': request.model,
    'prompt': request.prompt,
    'image': request.image,
    'strength': request.strength,
    'add_original_image': request.addOriginalImage,
    if (request.size != null) 'size': request.size,
    if (request.width != null) 'width': request.width,
    if (request.height != null) 'height': request.height,
    'scale': request.scale,
    'cfg_rescale': request.cfgRescale,
    'sampler': request.sampler,
    'noise_schedule': request.noiseSchedule,
    if (request.seed != null) 'seed': request.seed,
    if (request.negativePrompt != null)
      'negative_prompt': request.negativePrompt,
    'quality': request.quality,
    'ucPreset': request.ucPreset,
    'response_format': request.responseFormat,
    if (request.imageFormat != null) 'image_format': request.imageFormat,
  }, patches);
}
