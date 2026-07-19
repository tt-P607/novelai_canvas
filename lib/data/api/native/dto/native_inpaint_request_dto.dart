import '../../common/api_request_builder.dart';
import 'native_generation_parameters_dto.dart';

class NativeInpaintRequestDto {
  NativeInpaintRequestDto({
    required this.prompt,
    required this.model,
    required this.parameters,
    required this.image,
    required this.mask,
    this.strength = 0.7,
    this.inpaintStrength = 1,
    this.noise = 0,
    int? extraNoiseSeed,
  }) : extraNoiseSeed = extraNoiseSeed ?? parameters.seed;

  final String prompt;
  final String model;
  final NativeGenerationParametersDto parameters;
  final String image;
  final String mask;
  final double strength;
  final double inpaintStrength;
  final double noise;
  final int extraNoiseSeed;
}

class NativeInpaintRequestBuilder
    implements ApiRequestBuilder<NativeInpaintRequestDto> {
  const NativeInpaintRequestBuilder();

  @override
  int get templateVersion => 1;

  @override
  JsonMap build(
    NativeInpaintRequestDto request, {
    List<JsonMap> patches = const [],
  }) {
    final model = request.model.endsWith('-inpainting')
        ? request.model
        : '${request.model}-inpainting';
    final parameters = request.parameters.toJson()
      ..addAll({
        'image': request.image,
        'mask': request.mask,
        'strength': request.strength,
        'noise': request.noise,
        'extra_noise_seed': request.extraNoiseSeed,
        'img2img': {'color_correct': true, 'strength': request.inpaintStrength},
        'inpaintImg2ImgStrength': request.inpaintStrength,
      });
    return applyRequestPatches({
      'input': request.prompt,
      'model': model,
      'action': 'infill',
      'parameters': parameters,
      'use_new_shared_trial': true,
    }, patches);
  }
}
