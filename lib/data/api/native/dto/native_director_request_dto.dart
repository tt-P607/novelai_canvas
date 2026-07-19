import '../../common/api_request_builder.dart';

enum NativeDirectorTool {
  declutter('declutter'),
  backgroundRemoval('bg-removal'),
  lineart('lineart'),
  sketch('sketch'),
  colorize('colorize'),
  emotion('emotion');

  const NativeDirectorTool(this.requestType);
  final String requestType;
}

class NativeDirectorRequestDto {
  const NativeDirectorRequestDto({
    required this.tool,
    required this.image,
    required this.width,
    required this.height,
    this.prompt = '',
    this.defry = 0,
  });

  final NativeDirectorTool tool;
  final String image;
  final int width;
  final int height;
  final String prompt;
  final int defry;
}

class NativeDirectorRequestBuilder
    implements ApiRequestBuilder<NativeDirectorRequestDto> {
  const NativeDirectorRequestBuilder();

  @override
  int get templateVersion => 1;

  @override
  JsonMap build(
    NativeDirectorRequestDto request, {
    List<JsonMap> patches = const [],
  }) => applyRequestPatches({
    'req_type': request.tool.requestType,
    'image': request.image,
    'width': request.width,
    'height': request.height,
    'prompt': request.prompt,
    'defry': request.defry,
  }, patches);
}
