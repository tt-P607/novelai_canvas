import 'package:dio/dio.dart';

import '../../../../core/network/json_patch_applier.dart';
import '../../../../domain/entities/image_generation_result.dart';
import '../dto/native_image_to_image_request_dto.dart';
import '../native_api_service.dart';

class NativeImageToImageService extends NativeApiService {
  NativeImageToImageService(
    super.client, {
    NativeImageToImageRequestBuilder? builder,
  }) : builder = builder ?? const NativeImageToImageRequestBuilder();

  final NativeImageToImageRequestBuilder builder;

  Future<ImageGenerationResult> generate(
    NativeImageToImageRequestDto request, {
    List<JsonMap> patches = const [],
    CancelToken? cancelToken,
  }) => postZip(
    '/ai/generate-image',
    data: builder.build(request, patches: patches),
    cancelToken: cancelToken,
  );
}
