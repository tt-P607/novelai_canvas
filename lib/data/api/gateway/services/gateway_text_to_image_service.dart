import 'package:dio/dio.dart';

import '../../../../core/network/json_patch_applier.dart';
import '../../../../domain/entities/image_generation_result.dart';
import '../dto/gateway_text_to_image_request_dto.dart';
import '../gateway_api_service.dart';

/// Gateway text-to-image via the OpenAI-compatible `/v1/images/generations`
/// endpoint. new-api registers only this image endpoint (no
/// `/v1/chat/completions`), so all gateway text-to-image, multi-character and
/// Vibe requests go through here with NovelAI params nested in `params`.
class GatewayTextToImageService extends GatewayApiService {
  GatewayTextToImageService(
    super.client, {
    GatewayTextToImageRequestBuilder? builder,
  }) : builder = builder ?? const GatewayTextToImageRequestBuilder();

  final GatewayTextToImageRequestBuilder builder;

  Future<ImageGenerationResult> generate(
    GatewayTextToImageRequestDto request, {
    List<JsonMap> patches = const [],
    CancelToken? cancelToken,
  }) => postImageJson(
    '/v1/images/generations',
    data: builder.build(request, patches: patches),
    cancelToken: cancelToken,
  );
}
