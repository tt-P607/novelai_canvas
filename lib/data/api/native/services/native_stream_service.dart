import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/network/image_response_decoder.dart';
import '../../../../core/network/json_patch_applier.dart';
import '../../../../core/network/network_error_mapper.dart';
import '../dto/native_stream_dto.dart';

class NativeStreamService {
  NativeStreamService(this.client, {NativeStreamRequestBuilder? builder})
    : builder = builder ?? const NativeStreamRequestBuilder();

  final Dio client;
  final NativeStreamRequestBuilder builder;

  Stream<NativeStreamEventDto> generate(
    NativeStreamRequestDto request, {
    List<JsonMap> patches = const [],
  }) async* {
    try {
      final response = await client.post<ResponseBody>(
        '/ai/generate-image-stream',
        data: builder.build(request, patches: patches),
        options: Options(
          responseType: ResponseType.stream,
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream',
            'Origin': 'https://novelai.net',
            'Referer': 'https://novelai.net/',
          },
        ),
      );
      final body = response.data;
      if (body == null) return;
      final lines = body.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        final event = parseNativeSseData(line);
        if (event != null) yield event;
      }
    } catch (error) {
      throw NetworkErrorMapper.map(error);
    }
  }

  Uint8List decodeEventImage(NativeStreamEventDto event) =>
      ImageResponseDecoder.decodeBase64Image(event.image);
}
