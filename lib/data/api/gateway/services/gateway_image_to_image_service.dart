import 'package:dio/dio.dart';

import '../../../../core/network/json_patch_applier.dart';
import '../../../../domain/entities/image_generation_result.dart';
import '../dto/gateway_image_to_image_request_dto.dart';
import '../gateway_api_service.dart';

class GatewayImageToImageService extends GatewayApiService {
  GatewayImageToImageService(
    super.client, {
    GatewayImageToImageRequestBuilder? builder,
  }) : builder = builder ?? const GatewayImageToImageRequestBuilder();
  final GatewayImageToImageRequestBuilder builder;
  Future<ImageGenerationResult> generate(
    GatewayImageToImageRequestDto request, {
    List<JsonMap> patches = const [],
    CancelToken? cancelToken,
  }) => postImageJson(
    '/v1/images/img2img',
    data: builder.build(request, patches: patches),
    cancelToken: cancelToken,
  );
}
