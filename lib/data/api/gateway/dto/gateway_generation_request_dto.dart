import '../../common/api_request_builder.dart';

class GatewayGenerationRequestDto {
  const GatewayGenerationRequestDto({
    required this.model,
    required this.prompt,
    this.size = '1024x1024',
    this.responseFormat = 'url',
  });
  final String model;
  final String prompt;
  final String size;
  final String responseFormat;
}

class GatewayGenerationRequestBuilder
    implements ApiRequestBuilder<GatewayGenerationRequestDto> {
  const GatewayGenerationRequestBuilder();
  @override
  int get templateVersion => 1;
  @override
  JsonMap build(
    GatewayGenerationRequestDto request, {
    List<JsonMap> patches = const [],
  }) => applyRequestPatches({
    'model': request.model,
    'prompt': request.prompt,
    'size': request.size,
    'response_format': request.responseFormat,
  }, patches);
}
