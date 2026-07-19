import 'package:dio/dio.dart';

import '../../../../core/network/json_patch_applier.dart';
import '../../../../domain/entities/image_generation_result.dart';
import '../dto/gateway_vibe_transfer_request_dto.dart';
import '../gateway_api_service.dart';

class GatewayVibeTransferService extends GatewayApiService {
  GatewayVibeTransferService(
    super.client, {
    GatewayVibeTransferRequestBuilder? builder,
  }) : builder = builder ?? const GatewayVibeTransferRequestBuilder();
  final GatewayVibeTransferRequestBuilder builder;
  Future<ImageGenerationResult> generate(
    GatewayVibeTransferRequestDto request, {
    List<JsonMap> patches = const [],
    CancelToken? cancelToken,
  }) => postImageJson(
    '/v1/images/vibe-transfer',
    data: builder.build(request, patches: patches),
    cancelToken: cancelToken,
  );
}
