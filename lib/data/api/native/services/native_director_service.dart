import 'package:dio/dio.dart';

import '../../../../core/network/json_patch_applier.dart';
import '../../../../domain/entities/image_generation_result.dart';
import '../dto/native_director_request_dto.dart';
import '../native_api_service.dart';

class NativeDirectorService extends NativeApiService {
  NativeDirectorService(super.client, {NativeDirectorRequestBuilder? builder})
    : builder = builder ?? const NativeDirectorRequestBuilder();

  final NativeDirectorRequestBuilder builder;

  Future<ImageGenerationResult> augment(
    NativeDirectorRequestDto request, {
    List<JsonMap> patches = const [],
    CancelToken? cancelToken,
  }) => postZip(
    '/ai/augment-image',
    data: builder.build(request, patches: patches),
    cancelToken: cancelToken,
  );
}
