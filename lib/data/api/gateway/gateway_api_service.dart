import 'dart:convert';
import 'dart:developer';

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
    } on DioException catch (error) {
      // Streaming responses arrive as ResponseBody; drain the bytes so the real
      // upstream error text reaches both adb logcat and the user-facing message.
      final drained = await _drainStreamBody(error.response?.data);
      log(
        '[GatewayApiService.postImageJson] DioException '
        'type=${error.type} statusCode=${error.response?.statusCode} '
        'path=$path uri=${error.requestOptions.uri} '
        'response=${drained ?? _truncateForLog(error.response?.data)}',
      );
      final mapped = drained == null
          ? error
          : DioException(
              requestOptions: error.requestOptions,
              response: error.response == null
                  ? null
                  : Response(
                      requestOptions: error.requestOptions,
                      statusCode: error.response!.statusCode ?? 0,
                      data: drained,
                      headers: error.response!.headers,
                    ),
              type: error.type,
              error: error.error,
            );
      throw NetworkErrorMapper.map(mapped);
    } catch (error) {
      log('[GatewayApiService.postImageJson] non-Dio error: $error');
      throw NetworkErrorMapper.map(error);
    }
  }

  /// Reads up to 2 KB from a streamed [ResponseBody] so the real error text
  /// can be surfaced in logs instead of the opaque `<ResponseBody>` type name.
  static Future<String?> _drainStreamBody(Object? data) async {
    if (data is! ResponseBody) return null;
    try {
      final bytes = <int>[];
      await for (final chunk in data.stream) {
        bytes.addAll(chunk);
        if (bytes.length >= 2048) break;
      }
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  static String _truncateForLog(Object? value) {
    if (value == null) return '<null>';
    String text;
    if (value is String) {
      text = value;
    } else if (value is List<int>) {
      text = utf8.decode(value, allowMalformed: true);
    } else {
      try {
        text = jsonEncode(value);
      } catch (_) {
        text = '<${value.runtimeType}>';
      }
    }
    if (text.length <= 500) return text;
    return '${text.substring(0, 500)}…';
  }
}
