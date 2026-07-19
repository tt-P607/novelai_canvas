import '../../common/api_request_builder.dart';

class NativeUpscaleRequestDto {
  const NativeUpscaleRequestDto({
    required this.image,
    required this.width,
    required this.height,
    this.scale = 4,
  });

  final String image;
  final int width;
  final int height;
  final int scale;
}

class NativeUpscaleRequestBuilder
    implements ApiRequestBuilder<NativeUpscaleRequestDto> {
  const NativeUpscaleRequestBuilder();

  @override
  int get templateVersion => 1;

  @override
  JsonMap build(
    NativeUpscaleRequestDto request, {
    List<JsonMap> patches = const [],
  }) => applyRequestPatches({
    'image': request.image,
    'width': request.width,
    'height': request.height,
    'scale': request.scale,
  }, patches);
}
