import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novelai_canvas/core/network/backend_mode.dart';
import 'package:novelai_canvas/data/api/gateway/services/gateway_generation_service.dart';
import 'package:novelai_canvas/data/api/gateway/services/gateway_image_to_image_service.dart';
import 'package:novelai_canvas/data/api/gateway/services/gateway_inpaint_service.dart';
import 'package:novelai_canvas/data/api/native/services/native_image_to_image_service.dart';
import 'package:novelai_canvas/data/api/native/services/native_inpaint_service.dart';
import 'package:novelai_canvas/data/api/native/services/native_stream_service.dart';
import 'package:novelai_canvas/data/api/native/services/native_text_to_image_service.dart';
import 'package:novelai_canvas/data/repositories/generation_repository_impl.dart';
import 'package:novelai_canvas/domain/entities/generation_task.dart';

void main() {
  test('统一生成仓库按任务快照路由原生和网关文生图', () async {
    final nativeDio = Dio()..httpClientAdapter = _GenerationAdapter();
    final gatewayDio = Dio()..httpClientAdapter = _GenerationAdapter();
    final repository = _repository(nativeDio, gatewayDio);

    final native = await repository.execute(_task(BackendMode.native));
    final gateway = await repository.execute(_task(BackendMode.gateway));

    expect(native.images.single.bytes, [1, 2, 3]);
    expect(gateway.images.single.bytes, [4, 5, 6]);
    final adapter = gatewayDio.httpClientAdapter as _GenerationAdapter;
    expect(adapter.lastPath, '/v1/images/generations');
    expect(adapter.lastJson?['response_format'], 'b64_json');
  });

  test('统一生成仓库 materialize 网关 URL 图片', () async {
    final gatewayDio = Dio()
      ..httpClientAdapter = _GenerationAdapter(useUrl: true);
    final downloadDio = Dio()..httpClientAdapter = _DownloadAdapter();
    final repository = _repository(
      Dio()..httpClientAdapter = _GenerationAdapter(),
      gatewayDio,
      downloadDio: downloadDio,
    );

    final result = await repository.execute(_task(BackendMode.gateway));

    expect(result.images.single.bytes, [9, 8, 7]);
  });
}

GenerationRepositoryImpl _repository(
  Dio nativeDio,
  Dio gatewayDio, {
  Dio? downloadDio,
}) => GenerationRepositoryImpl(
  nativeTextToImageService: NativeTextToImageService(nativeDio),
  nativeImageToImageService: NativeImageToImageService(nativeDio),
  nativeInpaintService: NativeInpaintService(nativeDio),
  nativeStreamService: NativeStreamService(nativeDio),
  gatewayGenerationService: GatewayGenerationService(gatewayDio),
  gatewayImageToImageService: GatewayImageToImageService(gatewayDio),
  gatewayInpaintService: GatewayInpaintService(gatewayDio),
  downloadClient: downloadDio,
);

GenerationTask _task(BackendMode backendMode) {
  final now = DateTime.utc(2026, 7, 19);
  return GenerationTask(
    id: backendMode.name,
    spec: GenerationSpec(
      mode: GenerationMode.textToImage,
      backendMode: backendMode,
      model: 'nai-diffusion-4-5-full',
      prompt: '1girl',
      negativePrompt: '',
      width: 832,
      height: 1216,
      steps: 28,
      scale: 5,
      cfgRescale: 0,
      sampler: 'k_euler_ancestral',
      noiseSchedule: 'karras',
      seed: 1,
    ),
    status: GenerationTaskStatus.queued,
    createdAt: now,
    updatedAt: now,
  );
}

class _GenerationAdapter implements HttpClientAdapter {
  _GenerationAdapter({this.useUrl = false});

  final bool useUrl;
  String? lastPath;
  Map<String, Object?>? lastJson;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastPath = options.path;
    lastJson = options.data is Map
        ? Map<String, Object?>.from(options.data as Map)
        : null;
    if (options.path.startsWith('/v1/')) {
      return ResponseBody.fromString(
        jsonEncode({
          'data': [
            if (useUrl)
              {'url': 'https://cdn.example.com/result.png'}
            else
              {
                'b64_json': base64Encode([4, 5, 6]),
              },
          ],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    final archive = Archive()
      ..addFile(ArchiveFile('image.png', 3, Uint8List.fromList([1, 2, 3])));
    return ResponseBody.fromBytes(ZipEncoder().encode(archive), 200);
  }

  @override
  void close({bool force = false}) {}
}

class _DownloadAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes(
    [9, 8, 7],
    200,
    headers: {
      Headers.contentTypeHeader: ['image/png'],
    },
  );

  @override
  void close({bool force = false}) {}
}
