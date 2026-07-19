import 'package:dio/dio.dart';

import '../../../../core/network/json_patch_applier.dart';
import '../../../../domain/entities/image_generation_result.dart';
import '../dto/gateway_inpaint_request_dto.dart';
import '../gateway_api_service.dart';

class GatewayInpaintService extends GatewayApiService {
  GatewayInpaintService(super.client, {GatewayInpaintRequestBuilder? builder})
    : builder = builder ?? const GatewayInpaintRequestBuilder();
  final GatewayInpaintRequestBuilder builder;
  Future<ImageGenerationResult> generate(
    GatewayInpaintRequestDto request, {
    List<JsonMap> patches = const [],
    CancelToken? cancelToken,
  }) => postImageJson(
    '/v1/images/inpainting',
    data: builder.build(request, patches: patches),
    cancelToken: cancelToken,
  );
}
