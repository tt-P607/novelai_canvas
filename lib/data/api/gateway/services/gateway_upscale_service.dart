import '../../../../core/network/json_patch_applier.dart';
import 'package:dio/dio.dart';

import '../../../../domain/entities/image_generation_result.dart';
import '../dto/gateway_upscale_request_dto.dart';
import '../gateway_api_service.dart';

class GatewayUpscaleService extends GatewayApiService {
  GatewayUpscaleService(super.client, {GatewayUpscaleRequestBuilder? builder})
    : builder = builder ?? const GatewayUpscaleRequestBuilder();
  final GatewayUpscaleRequestBuilder builder;
  Future<ImageGenerationResult> upscale(
    GatewayUpscaleRequestDto request, {
    List<JsonMap> patches = const [],
    CancelToken? cancelToken,
  }) => postImageJson(
    '/v1/images/upscale',
    data: builder.build(request, patches: patches),
    cancelToken: cancelToken,
  );
}
