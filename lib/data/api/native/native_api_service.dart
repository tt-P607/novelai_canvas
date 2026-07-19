import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/image_response_decoder.dart';
import '../../../core/network/network_error_mapper.dart';
import '../../../domain/entities/image_generation_result.dart';
import '../common/json_helpers.dart';

abstract class NativeApiService {
  const NativeApiService(this.client);

  final Dio client;

  Future<ImageGenerationResult> postZip(
    String path, {
    required Object data,
    String? baseUrl,
  }) async {
    try {
      final response = await client.post<List<int>>(
        path,
        data: data,
        options: Options(
          responseType: ResponseType.bytes,
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/zip',
            'Origin': 'https://novelai.net',
            'Referer': 'https://novelai.net/',
          },
        ),
        queryParameters: null,
      );
      final bytes = Uint8List.fromList(response.data ?? const []);
      return ImageGenerationResult(
        images: ImageResponseDecoder.decodeZip(bytes),
        anlasCost: parseHeaderInt(response.headers.map, 'x-anlas-cost'),
        requestId: response.headers.value('x-request-id'),
      );
    } catch (error) {
      throw NetworkErrorMapper.map(error);
    }
  }
}
