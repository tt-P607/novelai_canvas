import '../../common/api_request_builder.dart';

enum GatewayDirectorTool {
  declutter('director-declutter'),
  backgroundRemoval('director-bg-remover'),
  lineart('director-lineart'),
  sketch('director-sketch'),
  colorize('director-colorize'),
  emotion('director-emotion');

  const GatewayDirectorTool(this.model);
  final String model;
}

class GatewayDirectorRequestDto {
  const GatewayDirectorRequestDto({
    required this.tool,
    required this.image,
    this.model = 'nai-diffusion-4-5-full',
    this.width,
    this.height,
    this.prompt,
    this.defry,
    this.responseFormat = 'url',
  });
  final GatewayDirectorTool tool;
  final String image;
  final String model;
  final int? width;
  final int? height;
  final String? prompt;
  final int? defry;
  final String responseFormat;
}

class GatewayDirectorRequestBuilder
    implements ApiRequestBuilder<GatewayDirectorRequestDto> {
  const GatewayDirectorRequestBuilder();
  @override
  int get templateVersion => 1;
  @override
  JsonMap build(
    GatewayDirectorRequestDto request, {
    List<JsonMap> patches = const [],
  }) => applyRequestPatches({
    'model': request.model,
    'extra': request.tool.model,
    'image': request.image,
    if (request.width != null) 'width': request.width,
    if (request.height != null) 'height': request.height,
    if (request.prompt != null) 'prompt': request.prompt,
    if (request.defry != null) 'defry': request.defry,
    'response_format': request.responseFormat,
  }, patches);
}
