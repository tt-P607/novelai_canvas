import 'package:dio/dio.dart';

import '../../../../core/network/json_patch_applier.dart';
import '../../../../domain/entities/image_generation_result.dart';
import '../dto/native_upscale_request_dto.dart';
import '../native_api_service.dart';

class NativeUpscaleService extends NativeApiService {
  NativeUpscaleService(super.client, {NativeUpscaleRequestBuilder? builder})
    : builder = builder ?? const NativeUpscaleRequestBuilder();

  final NativeUpscaleRequestBuilder builder;

  Future<ImageGenerationResult> upscale(
    NativeUpscaleRequestDto request, {
    List<JsonMap> patches = const [],
    CancelToken? cancelToken,
  }) => postZip(
    '/ai/upscale',
    data: builder.build(request, patches: patches),
    cancelToken: cancelToken,
  );
}
