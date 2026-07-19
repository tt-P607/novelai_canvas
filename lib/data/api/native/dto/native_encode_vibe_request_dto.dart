import '../../common/api_request_builder.dart';

class NativeEncodeVibeRequestDto {
  const NativeEncodeVibeRequestDto({
    required this.image,
    required this.model,
    this.informationExtracted = 0.7,
  });

  final String image;
  final String model;
  final double informationExtracted;
}

class NativeEncodeVibeRequestBuilder
    implements ApiRequestBuilder<NativeEncodeVibeRequestDto> {
  const NativeEncodeVibeRequestBuilder();

  @override
  int get templateVersion => 1;

  @override
  JsonMap build(
    NativeEncodeVibeRequestDto request, {
    List<JsonMap> patches = const [],
  }) => applyRequestPatches({
    'image': request.image,
    'information_extracted': request.informationExtracted,
    'model': request.model,
  }, patches);
}
