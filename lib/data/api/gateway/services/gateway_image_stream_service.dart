import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/network/network_error_mapper.dart';
import '../../native/dto/native_stream_dto.dart';
import '../gateway_api_service.dart';

/// Streams NovelAI intermediate/final frames through the unified gateway
/// image endpoint `/v1/images/generations` with `stream: true` in the request
/// body. The gateway dispatches text-to-image / img2img / inpainting based on
/// the presence of `image` / `mask` fields.
///
/// The gateway forwards the upstream NovelAI SSE verbatim, so the events are
/// parsed with the same [parseNativeSseData] used for the native stream.
class GatewayImageStreamService extends GatewayApiService {
  GatewayImageStreamService(super.client);

  Stream<NativeStreamEventDto> generate(
    String path, {
    required Object data,
    CancelToken? cancelToken,
  }) async* {
    try {
      final response = await client.post<ResponseBody>(
        path,
        data: data,
        // OpenAI 兼容代理（如 newapi）依据该头决定是否透传 SSE，
        // 缺失时会把流式响应缓冲为普通 JSON，破坏渐进式预览。
        options: Options(
          responseType: ResponseType.stream,
          headers: const {'Accept': 'text/event-stream'},
        ),
        cancelToken: cancelToken,
      );
      final body = response.data;
      if (body == null) return;
      final lines = body.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        final event = parseNativeSseData(line);
        if (event == null) continue;
        if (event.isError) {
          throw Exception('流式生成中途失败：${event.errorMessage ?? '未知错误'}');
        }
        yield event;
      }
    } catch (error) {
      throw NetworkErrorMapper.map(error);
    }
  }
}
