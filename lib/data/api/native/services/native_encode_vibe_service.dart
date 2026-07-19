import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/network/json_patch_applier.dart';
import '../../../../core/network/network_error_mapper.dart';
import '../dto/native_encode_vibe_request_dto.dart';

class NativeEncodeVibeService {
  NativeEncodeVibeService(
    this.client, {
    NativeEncodeVibeRequestBuilder? builder,
  }) : builder = builder ?? const NativeEncodeVibeRequestBuilder();

  final Dio client;
  final NativeEncodeVibeRequestBuilder builder;

  Future<String> encode(
    NativeEncodeVibeRequestDto request, {
    List<JsonMap> patches = const [],
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await client.post<List<int>>(
        '/ai/encode-vibe',
        data: builder.build(request, patches: patches),
        options: Options(responseType: ResponseType.bytes),
        cancelToken: cancelToken,
      );
      return base64Encode(Uint8List.fromList(response.data ?? const []));
    } catch (error) {
      throw NetworkErrorMapper.map(error);
    }
  }
}
