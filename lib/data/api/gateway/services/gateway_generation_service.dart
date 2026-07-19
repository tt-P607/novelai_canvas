import '../../../../core/network/json_patch_applier.dart';
import '../../../../domain/entities/image_generation_result.dart';
import '../dto/gateway_generation_request_dto.dart';
import '../gateway_api_service.dart';

class GatewayGenerationService extends GatewayApiService {
  GatewayGenerationService(
    super.client, {
    GatewayGenerationRequestBuilder? builder,
  }) : builder = builder ?? const GatewayGenerationRequestBuilder();
  final GatewayGenerationRequestBuilder builder;
  Future<ImageGenerationResult> generate(
    GatewayGenerationRequestDto request, {
    List<JsonMap> patches = const [],
  }) => postImageJson(
    '/v1/images/generations',
    data: builder.build(request, patches: patches),
  );
}
