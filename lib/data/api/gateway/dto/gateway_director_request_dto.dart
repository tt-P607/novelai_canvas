import '../../common/api_request_builder.dart';

enum GatewayDirectorTool {
  declutter('/v1/images/director-declutter'),
  backgroundRemoval('/v1/images/director-bg-remover'),
  lineart('/v1/images/director-lineart'),
  sketch('/v1/images/director-sketch'),
  colorize('/v1/images/director-colorize'),
  emotion('/v1/images/director-emotion');

  const GatewayDirectorTool(this.path);
  final String path;
}

class GatewayDirectorRequestDto {
  const GatewayDirectorRequestDto({
    required this.tool,
    required this.image,
    this.width,
    this.height,
    this.prompt,
    this.defry,
    this.responseFormat = 'url',
  });
  final GatewayDirectorTool tool;
  final String image;
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
    'image': request.image,
    if (request.width != null) 'width': request.width,
    if (request.height != null) 'height': request.height,
    if (request.prompt != null) 'prompt': request.prompt,
    if (request.defry != null) 'defry': request.defry,
    'response_format': request.responseFormat,
  }, patches);
}
