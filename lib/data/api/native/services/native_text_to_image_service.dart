import '../../../../core/network/json_patch_applier.dart';
import '../../../../domain/entities/image_generation_result.dart';
import '../native_api_service.dart';
import '../dto/native_text_to_image_request_dto.dart';

class NativeTextToImageService extends NativeApiService {
  NativeTextToImageService(
    super.client, {
    NativeTextToImageRequestBuilder? builder,
  }) : builder = builder ?? const NativeTextToImageRequestBuilder();

  final NativeTextToImageRequestBuilder builder;

  Future<ImageGenerationResult> generate(
    NativeTextToImageRequestDto request, {
    List<JsonMap> patches = const [],
  }) => postZip(
    '/ai/generate-image',
    data: builder.build(request, patches: patches),
  );
}
