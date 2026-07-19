import '../../common/api_request_builder.dart';

class NativeTagSuggestionRequestDto {
  const NativeTagSuggestionRequestDto({
    required this.prompt,
    this.model = 'nai-diffusion-3',
  });

  final String prompt;
  final String model;
}

class NativeTagSuggestionRequestBuilder
    implements ApiRequestBuilder<NativeTagSuggestionRequestDto> {
  const NativeTagSuggestionRequestBuilder();

  @override
  int get templateVersion => 1;

  @override
  JsonMap build(
    NativeTagSuggestionRequestDto request, {
    List<JsonMap> patches = const [],
  }) => applyRequestPatches({
    'model': request.model,
    'prompt': request.prompt,
  }, patches);
}
