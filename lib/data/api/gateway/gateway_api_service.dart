import 'package:dio/dio.dart';

import '../../../core/network/image_response_decoder.dart';
import '../../../core/network/network_error_mapper.dart';
import '../../../domain/entities/image_generation_result.dart';
import '../common/json_helpers.dart';

abstract class GatewayApiService {
  const GatewayApiService(this.client);

  final Dio client;

  Future<ImageGenerationResult> postImageJson(
    String path, {
    required Object data,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await client.post<Object?>(
        path,
        data: data,
        options: options,
        cancelToken: cancelToken,
      );
      final json = asJsonMap(response.data);
      final created = (json['created'] as num?)?.toInt();
      return ImageGenerationResult(
        images: ImageResponseDecoder.decodeOpenAiImages(json),
        createdAt: created == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(created * 1000),
        anlasCost: parseHeaderInt(response.headers.map, 'x-anlas-cost'),
        requestId: response.headers.value('x-request-id'),
      );
    } catch (error) {
      throw NetworkErrorMapper.map(error);
    }
  }
}
