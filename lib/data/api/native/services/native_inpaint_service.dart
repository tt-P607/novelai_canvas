import '../../../../core/network/json_patch_applier.dart';
import '../../../../domain/entities/image_generation_result.dart';
import '../dto/native_inpaint_request_dto.dart';
import '../native_api_service.dart';

class NativeInpaintService extends NativeApiService {
  NativeInpaintService(super.client, {NativeInpaintRequestBuilder? builder})
    : builder = builder ?? const NativeInpaintRequestBuilder();

  final NativeInpaintRequestBuilder builder;

  Future<ImageGenerationResult> generate(
    NativeInpaintRequestDto request, {
    List<JsonMap> patches = const [],
  }) => postZip(
    '/ai/generate-image',
    data: builder.build(request, patches: patches),
  );
}
