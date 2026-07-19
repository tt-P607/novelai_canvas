import '../../common/api_request_builder.dart';

class GatewayUpscaleRequestDto {
  const GatewayUpscaleRequestDto({
    required this.image,
    this.width,
    this.height,
    this.responseFormat = 'url',
  });
  final String image;
  final int? width;
  final int? height;
  final String responseFormat;
}

class GatewayUpscaleRequestBuilder
    implements ApiRequestBuilder<GatewayUpscaleRequestDto> {
  const GatewayUpscaleRequestBuilder();
  @override
  int get templateVersion => 1;
  @override
  JsonMap build(
    GatewayUpscaleRequestDto request, {
    List<JsonMap> patches = const [],
  }) => applyRequestPatches({
    'image': request.image,
    if (request.width != null) 'width': request.width,
    if (request.height != null) 'height': request.height,
    'response_format': request.responseFormat,
  }, patches);
}
