import 'package:dio/dio.dart';

import '../../../../core/network/json_patch_applier.dart';
import '../../../../domain/entities/image_generation_result.dart';
import '../dto/gateway_edits_request_dto.dart';
import '../gateway_api_service.dart';

class GatewayEditsService extends GatewayApiService {
  GatewayEditsService(super.client, {GatewayEditsRequestBuilder? builder})
    : builder = builder ?? const GatewayEditsRequestBuilder();
  final GatewayEditsRequestBuilder builder;
  Future<ImageGenerationResult> edit(
    GatewayEditsRequestDto request, {
    List<JsonMap> patches = const [],
  }) => postImageJson(
    '/v1/images/edits',
    data: request.isMultipart
        ? builder.buildMultipart(request)
        : builder.build(request, patches: patches),
    options: request.isMultipart
        ? Options(contentType: Headers.multipartFormDataContentType)
        : null,
  );
}
