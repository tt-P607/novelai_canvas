import 'package:dio/dio.dart';

import '../../../../core/network/json_patch_applier.dart';
import '../../../../domain/entities/image_generation_result.dart';
import '../dto/gateway_director_request_dto.dart';
import '../gateway_api_service.dart';

abstract class GatewayDirectorEndpointService extends GatewayApiService {
  GatewayDirectorEndpointService(
    super.client,
    this.tool, {
    GatewayDirectorRequestBuilder? builder,
  }) : builder = builder ?? const GatewayDirectorRequestBuilder();

  final GatewayDirectorTool tool;
  final GatewayDirectorRequestBuilder builder;

  Future<ImageGenerationResult> process(
    GatewayDirectorRequestDto request, {
    List<JsonMap> patches = const [],
    CancelToken? cancelToken,
  }) {
    if (request.tool != tool) {
      throw ArgumentError('导演工具请求与端点 Service 不匹配。');
    }
    return postImageJson(
      tool.path,
      data: builder.build(request, patches: patches),
      cancelToken: cancelToken,
    );
  }
}

class GatewayDeclutterService extends GatewayDirectorEndpointService {
  GatewayDeclutterService(Dio client)
    : super(client, GatewayDirectorTool.declutter);
}

class GatewayBackgroundRemovalService extends GatewayDirectorEndpointService {
  GatewayBackgroundRemovalService(Dio client)
    : super(client, GatewayDirectorTool.backgroundRemoval);
}

class GatewayLineartService extends GatewayDirectorEndpointService {
  GatewayLineartService(Dio client)
    : super(client, GatewayDirectorTool.lineart);
}

class GatewaySketchService extends GatewayDirectorEndpointService {
  GatewaySketchService(Dio client) : super(client, GatewayDirectorTool.sketch);
}

class GatewayColorizeService extends GatewayDirectorEndpointService {
  GatewayColorizeService(Dio client)
    : super(client, GatewayDirectorTool.colorize);
}

class GatewayEmotionService extends GatewayDirectorEndpointService {
  GatewayEmotionService(Dio client)
    : super(client, GatewayDirectorTool.emotion);
}
