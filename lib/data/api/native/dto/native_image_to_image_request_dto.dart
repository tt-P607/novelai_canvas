import '../../common/api_request_builder.dart';
import 'native_generation_parameters_dto.dart';

class NativeImageToImageRequestDto {
  NativeImageToImageRequestDto({
    required this.prompt,
    required this.model,
    required this.parameters,
    required this.image,
    this.strength = 0.7,
    this.noise = 0,
    int? extraNoiseSeed,
  }) : extraNoiseSeed = extraNoiseSeed ?? parameters.seed;

  final String prompt;
  final String model;
  final NativeGenerationParametersDto parameters;
  final String image;
  final double strength;
  final double noise;
  final int extraNoiseSeed;
}

class NativeImageToImageRequestBuilder
    implements ApiRequestBuilder<NativeImageToImageRequestDto> {
  const NativeImageToImageRequestBuilder();

  @override
  int get templateVersion => 1;

  @override
  JsonMap build(
    NativeImageToImageRequestDto request, {
    List<JsonMap> patches = const [],
  }) {
    final parameters = request.parameters.toJson()
      ..addAll({
        'image': request.image,
        'strength': request.strength,
        'noise': request.noise,
        'extra_noise_seed': request.extraNoiseSeed,
        'img2img': {'color_correct': true, 'strength': request.strength},
        'inpaintImg2ImgStrength': request.strength,
      });
    return applyRequestPatches({
      'input': request.prompt,
      'model': request.model,
      'action': 'img2img',
      'parameters': parameters,
      'use_new_shared_trial': true,
    }, patches);
  }
}
