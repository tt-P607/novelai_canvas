import '../../common/api_request_builder.dart';

class GatewayTagSuggestionRequestDto {
  const GatewayTagSuggestionRequestDto({
    required this.prompt,
    this.model = 'nai-diffusion-3',
  });
  final String prompt;
  final String model;
}

class GatewayTagSuggestionRequestBuilder
    implements ApiRequestBuilder<GatewayTagSuggestionRequestDto> {
  const GatewayTagSuggestionRequestBuilder();
  @override
  int get templateVersion => 1;
  @override
  JsonMap build(
    GatewayTagSuggestionRequestDto request, {
    List<JsonMap> patches = const [],
  }) => applyRequestPatches({
    'prompt': request.prompt,
    'model': request.model,
  }, patches);
}
