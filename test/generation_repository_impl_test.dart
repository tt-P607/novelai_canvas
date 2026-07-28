import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novelai_canvas/core/network/backend_mode.dart';
import 'package:novelai_canvas/domain/entities/advanced_generation.dart';
import 'package:novelai_canvas/data/api/gateway/dto/gateway_text_to_image_request_dto.dart';
import 'package:novelai_canvas/data/api/gateway/services/gateway_chat_service.dart';
import 'package:novelai_canvas/data/api/gateway/services/gateway_image_to_image_service.dart';
import 'package:novelai_canvas/data/api/gateway/services/gateway_image_stream_service.dart';
import 'package:novelai_canvas/data/api/gateway/services/gateway_inpaint_service.dart';
import 'package:novelai_canvas/data/api/gateway/services/gateway_vibe_transfer_service.dart';
import 'package:novelai_canvas/data/api/native/services/native_encode_vibe_service.dart';
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
    final downloadDio = Dio()..httpClientAdapter = _DownloadAdapter();
    final repository = _repository(
      nativeDio,
      gatewayDio,
      downloadDio: downloadDio,
    );

    final native = await repository.execute(_task(BackendMode.native));
    final gateway = await repository.execute(_task(BackendMode.gateway));

    expect(native.images.single.bytes, [1, 2, 3]);
    // Gateway text-to-image now routes through /v1/chat/completions for
    // maximum proxy compatibility. The chat response carries a markdown
    // image URL which is materialised via the download client.
    expect(gateway.images.single.bytes, [9, 8, 7]);
    final adapter = gatewayDio.httpClientAdapter as _GenerationAdapter;
    expect(adapter.lastPath, '/v1/chat/completions');
    expect(adapter.lastJson?['response_format'], {'type': 'b64_json'});
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

  test('网关文生图流式使用统一图片端点并解析渐进帧', () async {
    final gatewayDio = Dio()..httpClientAdapter = _GenerationAdapter();
    final repository = _repository(
      Dio()..httpClientAdapter = _GenerationAdapter(),
      gatewayDio,
    );

    final previews = await repository
        .stream(_task(BackendMode.gateway))
        .toList();

    final adapter = gatewayDio.httpClientAdapter as _GenerationAdapter;
    expect(adapter.lastPath, '/v1/images/generations');
    expect(adapter.lastJson?['stream'], isTrue);
    expect(adapter.lastJson?['prompt'], '1girl');
    expect(adapter.lastJson?['steps'], 28);
    expect(previews.map((preview) => preview.step), [4, 28]);
    expect(previews.map((preview) => preview.isFinal), [false, true]);
    expect(previews.last.imageBytes, [7, 8, 9]);
  });

  test('网关文生图 Builder 保留生成参数和人物契约', () {
    final body = const GatewayTextToImageRequestBuilder().build(
      const GatewayTextToImageRequestDto(
        model: 'nai-diffusion-4-5-full',
        prompt: '1girl',
        width: 832,
        height: 1216,
        steps: 28,
        scale: 5,
        cfgRescale: 0,
        sampler: 'k_euler_ancestral',
        noiseSchedule: 'karras',
        seed: 42,
        negativePrompt: 'lowres',
        quality: true,
        ucPreset: 1,
        characters: [
          {
            'prompt': 'red hair',
            'negative_prompt': 'bad hands',
            'position': [0.3, 0.5],
            'enabled': true,
          },
        ],
      ),
    );

    expect(body['response_format'], 'b64_json');
    expect(body['negative_prompt'], 'lowres');
    expect(body['qualityToggle'], isTrue);
    expect((body['characters'] as List).single, {
      'prompt': 'red hair',
      'negative_prompt': 'bad hands',
      'position': [0.3, 0.5],
      'enabled': true,
    });
  });

  test('高级参数快照往返保留 Vibe、角色参考和多角色坐标', () {
    final spec = _task(BackendMode.native).spec;
    final advanced = GenerationSpec.fromJson({
      ...spec.toJson(),
      'characterPrompts': [
        const CharacterPrompt(
          prompt: 'red hair',
          negativePrompt: 'bad hands',
          position: CharacterPosition(x: 0.3, y: 0.5),
        ).toJson(),
      ],
      'vibeReferences': [
        const VibeReference(
          encodedData: 'encoded-vibe',
          strength: 0.6,
        ).toJson(),
      ],
      'characterReferences': [
        const CharacterReference(
          imagePath: 'reference.png',
          type: CharacterReferenceType.character,
        ).toJson(),
      ],
    });

    final restored = GenerationSpec.decode(advanced.encode());

    expect(restored.characterPrompts.single.position.x, 0.3);
    // Encoded payloads are stripped from snapshots; the vibe survives as a
    // placeholder that must be re-encoded on cold restore.
    expect(restored.vibeReferences.single.encodedData, isNull);
    expect(restored.vibeReferences.single.hasEncoding, isFalse);
    expect(
      restored.characterReferences.single.type,
      CharacterReferenceType.character,
    );
  });

  test('网关忽略禁用的 Vibe 并走普通文生图端点', () async {
    final gatewayDio = Dio()..httpClientAdapter = _GenerationAdapter();
    final repository = _repository(
      Dio()..httpClientAdapter = _GenerationAdapter(),
      gatewayDio,
      downloadDio: Dio()..httpClientAdapter = _DownloadAdapter(),
    );
    final base = _task(BackendMode.gateway);
    final task = GenerationTask(
      id: 'disabled-vibe',
      spec: GenerationSpec.fromJson({
        ...base.spec.toJson(),
        'vibeReferences': [
          const VibeReference(encodedData: 'IMPORTED', enabled: false).toJson(),
        ],
      }),
      status: base.status,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
    );

    await repository.execute(task);

    final adapter = gatewayDio.httpClientAdapter as _GenerationAdapter;
    expect(adapter.lastPath, '/v1/chat/completions');
  });

  test('网关多角色使用 Chat system message 契约', () async {
    final gatewayDio = Dio()..httpClientAdapter = _GenerationAdapter();
    final repository = _repository(
      Dio()..httpClientAdapter = _GenerationAdapter(),
      gatewayDio,
      downloadDio: Dio()..httpClientAdapter = _DownloadAdapter(),
    );
    final base = _task(BackendMode.gateway);
    final task = GenerationTask(
      id: 'characters',
      spec: GenerationSpec.fromJson({
        ...base.spec.toJson(),
        'characterPrompts': [
          const CharacterPrompt(
            prompt: 'red hair',
            position: CharacterPosition(x: 0.3, y: 0.5),
          ).toJson(),
        ],
      }),
      status: base.status,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
    );

    await repository.execute(task);

    final adapter = gatewayDio.httpClientAdapter as _GenerationAdapter;
    expect(adapter.lastPath, '/v1/chat/completions');
    final messages = adapter.lastJson?['messages'] as List;
    expect(
      (messages.last as Map)['content'].toString(),
      contains('Characters:'),
    );
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
  nativeEncodeVibeService: NativeEncodeVibeService(nativeDio),
  gatewayChatService: GatewayChatService(gatewayDio),
  gatewayVibeTransferService: GatewayVibeTransferService(gatewayDio),
  gatewayImageToImageService: GatewayImageToImageService(gatewayDio),
  gatewayInpaintService: GatewayInpaintService(gatewayDio),
  gatewayImageStreamService: GatewayImageStreamService(gatewayDio),
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
    if (options.path == '/v1/images/generations' &&
        lastJson?['stream'] == true) {
      final intermediate = base64Encode([1, 2, 3]);
      final finalImage = base64Encode([7, 8, 9]);
      return ResponseBody.fromString(
        'data: {"event_type":"intermediate","step_ix":4,"image":"$intermediate"}\n\n'
        'data: {"event_type":"final","step_ix":28,"image":"$finalImage"}\n\n'
        'data: [DONE]\n\n',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/event-stream'],
        },
      );
    }
    if (options.path == '/v1/chat/completions') {
      return ResponseBody.fromString(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': '![result](https://cdn.example.com/character.png)',
              },
            },
          ],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
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
