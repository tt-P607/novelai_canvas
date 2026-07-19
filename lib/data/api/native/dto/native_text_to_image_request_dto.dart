import '../../common/api_request_builder.dart';
import 'native_generation_parameters_dto.dart';

class NativeTextToImageRequestDto {
  const NativeTextToImageRequestDto({
    required this.prompt,
    required this.model,
    required this.parameters,
    this.useNewSharedTrial = true,
  });

  final String prompt;
  final String model;
  final NativeGenerationParametersDto parameters;
  final bool useNewSharedTrial;
}

class NativeTextToImageRequestBuilder
    implements ApiRequestBuilder<NativeTextToImageRequestDto> {
  const NativeTextToImageRequestBuilder();

  @override
  int get templateVersion => 1;

  @override
  JsonMap build(
    NativeTextToImageRequestDto request, {
    List<JsonMap> patches = const [],
  }) => applyRequestPatches({
    'input': request.prompt,
    'model': request.model,
    'action': 'generate',
    'parameters': request.parameters.toJson(),
    'use_new_shared_trial': request.useNewSharedTrial,
  }, patches);
}
