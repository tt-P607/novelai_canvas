import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/backend_mode.dart';
import '../../core/storage/character_reference_preprocessor.dart';
import '../../domain/entities/advanced_generation.dart';
import '../../domain/entities/generated_image.dart';
import '../../domain/entities/generation_task.dart';
import '../../domain/entities/image_generation_result.dart';
import '../../domain/entities/model_info.dart';
import '../../domain/repositories/generation_repository.dart';
import '../api/gateway/dto/gateway_image_to_image_request_dto.dart';
import '../api/gateway/dto/gateway_inpaint_request_dto.dart';
import '../api/gateway/dto/gateway_text_to_image_request_dto.dart';
import '../api/gateway/services/gateway_image_to_image_service.dart';
import '../api/gateway/services/gateway_inpaint_service.dart';
import '../api/gateway/services/gateway_text_to_image_service.dart';
import '../api/native/dto/native_encode_vibe_request_dto.dart';
import '../api/native/dto/native_generation_parameters_dto.dart';
import '../api/native/dto/native_image_to_image_request_dto.dart';
import '../api/native/dto/native_inpaint_request_dto.dart';
import '../api/native/dto/native_stream_dto.dart';
import '../api/native/dto/native_text_to_image_request_dto.dart';
import '../api/native/services/native_encode_vibe_service.dart';
import '../api/native/services/native_image_to_image_service.dart';
import '../api/native/services/native_inpaint_service.dart';
import '../api/native/services/native_stream_service.dart';
import '../api/native/services/native_text_to_image_service.dart';

class GenerationRepositoryImpl implements GenerationRepository {
  GenerationRepositoryImpl({
    required NativeTextToImageService nativeTextToImageService,
    required NativeImageToImageService nativeImageToImageService,
    required NativeInpaintService nativeInpaintService,
    required NativeStreamService nativeStreamService,
    required GatewayTextToImageService gatewayTextToImageService,
    required GatewayImageToImageService gatewayImageToImageService,
    required GatewayInpaintService gatewayInpaintService,
    required NativeEncodeVibeService nativeEncodeVibeService,
    Dio? downloadClient,
  }) : _nativeTextToImageService = nativeTextToImageService,
       _nativeImageToImageService = nativeImageToImageService,
       _nativeInpaintService = nativeInpaintService,
       _nativeStreamService = nativeStreamService,
       _gatewayTextToImageService = gatewayTextToImageService,
       _gatewayImageToImageService = gatewayImageToImageService,
       _gatewayInpaintService = gatewayInpaintService,
       _nativeEncodeVibeService = nativeEncodeVibeService,
       _downloadClient = downloadClient ?? Dio();

  final NativeTextToImageService _nativeTextToImageService;
  final NativeImageToImageService _nativeImageToImageService;
  final NativeInpaintService _nativeInpaintService;
  final NativeStreamService _nativeStreamService;
  final GatewayTextToImageService _gatewayTextToImageService;
  final GatewayImageToImageService _gatewayImageToImageService;
  final GatewayInpaintService _gatewayInpaintService;
  final NativeEncodeVibeService _nativeEncodeVibeService;
  final Dio _downloadClient;
  final Map<String, CancelToken> _cancelTokens = {};

  @override
  Future<GenerationExecutionResult> execute(GenerationTask task) async {
    final cancelToken = _createCancelToken(task.id);
    log(
      '[GenerationRepo] execute taskId=${task.id} '
      'backendMode=${task.spec.backendMode.name} '
      'mode=${task.spec.mode.name} stream=${task.spec.stream} '
      'model="${task.spec.model}"',
    );
    try {
      final result = switch (task.spec.backendMode) {
        BackendMode.native => await _executeNative(task, cancelToken),
        BackendMode.gateway => await _executeGateway(task, cancelToken),
      };
      final images = await Future.wait(
        result.images.map(
          (image) => _materializeImage(image, cancelToken: cancelToken),
        ),
      );
      return GenerationExecutionResult(
        images: images,
        anlasCost: result.anlasCost,
      );
    } finally {
      _cancelTokens.remove(task.id);
    }
  }

  @override
  Stream<GenerationPreview> stream(GenerationTask task) async* {
    final cancelToken = _createCancelToken(task.id);
    try {
      switch (task.spec.backendMode) {
        case BackendMode.native:
          // Native stream endpoint serves text-to-image, img2img and inpaint
          // from the same /ai/generate-image-stream path; the action is
          // determined by the payload, so _nativeRequest already builds the
          // correct body for any mode.
          final native = await _nativeRequest(
            task.spec,
            cancelToken: cancelToken,
          );
          final request = NativeStreamRequestDto(native.toPayload());
          await for (final event in _nativeStreamService.generate(
            request,
            cancelToken: cancelToken,
          )) {
            yield GenerationPreview(
              taskId: task.id,
              step: event.stepIndex,
              isFinal: event.isFinal,
              imageBytes: _nativeStreamService.decodeEventImage(event),
            );
          }
        case BackendMode.gateway:
          yield* _streamGateway(task, cancelToken);
      }
    } finally {
      _cancelTokens.remove(task.id);
    }
  }

  /// Gateway streaming falls back to Chat Completions SSE when the image
  /// endpoint cannot stream through OpenAI-compatible proxies (new-api etc.).
  ///
  /// Gateway streaming currently resolves through the non-streaming
  /// `/v1/images/generations` request and yields the final frame immediately.
  /// new-api does not expose `/v1/chat/completions` and its image SSE is a
  /// native NovelAI event stream, so a single final-frame preview is the
  /// reliable cross-gateway contract.
  Stream<GenerationPreview> _streamGateway(
    GenerationTask task,
    CancelToken cancelToken,
  ) async* {
    final result = await _executeGateway(task, cancelToken);
    for (final image in result.images) {
      final bytes = image.bytes;
      if (bytes != null) {
        yield GenerationPreview(
          taskId: task.id,
          step: 0,
          isFinal: true,
          imageBytes: bytes,
        );
      }
    }
  }

  @override
  Future<void> cancel(String taskId) async {
    _cancelTokens.remove(taskId)?.cancel('用户取消生成任务。');
  }

  Future<ImageGenerationResult> _executeNative(
    GenerationTask task,
    CancelToken cancelToken,
  ) async {
    final native = await _nativeRequest(task.spec, cancelToken: cancelToken);
    return switch (native) {
      _NativeTextToImage(:final dto) => _nativeTextToImageService.generate(
        dto,
        cancelToken: cancelToken,
      ),
      _NativeImageToImage(:final dto) => _nativeImageToImageService.generate(
        dto,
        cancelToken: cancelToken,
      ),
      _NativeInpaint(:final dto) => _nativeInpaintService.generate(
        dto,
        cancelToken: cancelToken,
      ),
    };
  }

  Future<ImageGenerationResult> _executeGateway(
    GenerationTask task,
    CancelToken cancelToken,
  ) async {
    final spec = task.spec;
    log(
      '[GenerationRepo] _executeGateway mode=${spec.mode.name} '
      'model="${spec.model}" prompt.len=${spec.prompt.length} '
      'vibes=${_enabledVibes(spec).length} '
      'characters=${spec.characterPrompts.length}',
    );
    return switch (spec.mode) {
      // All gateway text-to-image (plain, multi-character and Vibe) goes
      // through /v1/images/generations with NovelAI params nested in `params`
      // — new-api registers only this image endpoint.
      GenerationMode.textToImage => _gatewayTextToImageService.generate(
        await _gatewayTextToImageDto(spec),
        cancelToken: cancelToken,
      ),
      GenerationMode.imageToImage => _gatewayImageToImageService.generate(
        await _gatewayImg2ImgDto(spec),
        cancelToken: cancelToken,
      ),
      GenerationMode.inpaint => _gatewayInpaintService.generate(
        await _gatewayInpaintDto(spec),
        cancelToken: cancelToken,
      ),
    };
  }

  Future<GatewayImageToImageRequestDto> _gatewayImg2ImgDto(
    GenerationSpec spec,
  ) async => GatewayImageToImageRequestDto(
    model: spec.model,
    prompt: spec.prompt,
    image: await _readBase64(spec.sourceImagePath, '图生图源图片'),
    strength: spec.strength,
    noise: spec.noise,
    width: spec.width,
    height: spec.height,
    scale: spec.scale,
    cfgRescale: spec.cfgRescale,
    sampler: spec.sampler,
    noiseSchedule: spec.noiseSchedule,
    seed: spec.seed,
    negativePrompt: spec.negativePrompt,
    quality: spec.quality,
    ucPreset: spec.ucPreset.toString(),
    responseFormat: 'b64_json',
  );

  Future<GatewayInpaintRequestDto> _gatewayInpaintDto(
    GenerationSpec spec,
  ) async => GatewayInpaintRequestDto(
    model: spec.model,
    prompt: spec.prompt,
    image: await _readBase64(spec.sourceImagePath, '局部重绘源图片'),
    mask: await _readBase64(spec.maskImagePath, '局部重绘蒙版'),
    strength: spec.strength,
    noise: spec.noise,
    size: spec.size,
    width: spec.width,
    height: spec.height,
    scale: spec.scale,
    cfgRescale: spec.cfgRescale,
    sampler: spec.sampler,
    noiseSchedule: spec.noiseSchedule,
    seed: spec.seed,
    negativePrompt: spec.negativePrompt,
    quality: spec.quality,
    ucPreset: spec.ucPreset.toString(),
    responseFormat: 'b64_json',
  );

  /// Builds the request DTO once so plain and streaming generation can never
  /// drift apart: the streaming endpoint only re-serialises the same payload.
  Future<_NativeRequest> _nativeRequest(
    GenerationSpec spec, {
    CancelToken? cancelToken,
  }) async {
    final parameters = await _nativeParameters(spec, cancelToken: cancelToken);
    return switch (spec.mode) {
      GenerationMode.textToImage => _NativeTextToImage(
        NativeTextToImageRequestDto(
          prompt: spec.prompt,
          model: spec.model,
          parameters: parameters,
        ),
      ),
      GenerationMode.imageToImage => _NativeImageToImage(
        NativeImageToImageRequestDto(
          prompt: spec.prompt,
          model: spec.model,
          parameters: parameters,
          image: await _readBase64(spec.sourceImagePath, '图生图源图片'),
          strength: spec.strength,
          noise: spec.noise,
        ),
      ),
      GenerationMode.inpaint => _NativeInpaint(
        NativeInpaintRequestDto(
          prompt: spec.prompt,
          model: spec.model,
          parameters: parameters,
          image: await _readBase64(spec.sourceImagePath, '局部重绘源图片'),
          mask: await _readBase64(spec.maskImagePath, '局部重绘蒙版'),
          strength: spec.strength,
          noise: spec.noise,
        ),
      ),
    };
  }

  Future<NativeGenerationParametersDto> _nativeParameters(
    GenerationSpec spec, {
    CancelToken? cancelToken,
  }) async {
    final supportsVibe = BuiltInModels.supportsVibe(spec.model);
    final supportsCharacterReference = BuiltInModels.supportsCharacterReference(
      spec.model,
    );
    return NativeGenerationParametersDto(
      paramsVersion: BuiltInModels.isV5(spec.model) ? 4 : 3,
      width: spec.width,
      height: spec.height,
      seed: spec.seed,
      negativePrompt: spec.negativePrompt,
      steps: spec.steps,
      scale: spec.scale,
      sampler: spec.sampler,
      sampleCount: spec.sampleCount,
      noiseSchedule: spec.noiseSchedule,
      cfgRescale: spec.cfgRescale,
      qualityToggle: spec.quality,
      ucPreset: spec.ucPreset,
      addOriginalImage: spec.addOriginalImage,
      v4Prompt: V4PromptDto(
        baseCaption: spec.prompt,
        characterCaptions: _enabledCharacters(spec)
            .map(
              (character) => V4CharacterCaptionDto(
                caption: character.prompt,
                centers: [_nativeCenter(character.position)],
              ),
            )
            .toList(),
        useCoords: _enabledCharacters(spec).isNotEmpty,
      ),
      v4NegativePrompt: V4PromptDto(
        baseCaption: spec.negativePrompt,
        characterCaptions: _enabledCharacters(spec)
            .map(
              (character) => V4CharacterCaptionDto(
                caption: character.negativePrompt,
                centers: [_nativeCenter(character.position)],
              ),
            )
            .toList(),
        legacyUc: false,
      ),
      characterPrompts: _enabledCharacters(spec)
          .map(
            (character) => CharacterPromptDto(
              prompt: character.prompt,
              negativePrompt: character.negativePrompt,
              center: _nativeCenter(character.position),
            ),
          )
          .toList(),
      vibeData: supportsVibe
          ? await _nativeVibeData(spec, cancelToken: cancelToken)
          : const [],
      vibeStrengths: supportsVibe
          ? _enabledVibes(spec).map((reference) => reference.strength).toList()
          : const [],
      vibeInformationExtracted: supportsVibe
          ? _enabledVibes(
              spec,
            ).map((reference) => reference.informationExtracted).toList()
          : const [],
      directorReferences: supportsCharacterReference
          ? await Future.wait(
              spec.characterReferences
                  .where((reference) => reference.enabled)
                  .map(
                    (reference) async => DirectorReferenceDto(
                      image: await _readProcessedCharacterReference(
                        reference.imagePath,
                      ),
                      description: reference.description,
                      strength: reference.strength,
                      fidelity: reference.fidelity,
                      informationExtracted: reference.informationExtracted,
                    ),
                  ),
            )
          : const [],
      controlnetStrength: spec.controlnetStrength,
      normalizeReferenceStrength: spec.normalizeReferenceStrength,
    );
  }

  List<CharacterPrompt> _enabledCharacters(GenerationSpec spec) => spec
      .characterPrompts
      .where(
        (character) => character.enabled && character.prompt.trim().isNotEmpty,
      )
      .toList();

  List<VibeReference> _enabledVibes(GenerationSpec spec) => spec.vibeReferences
      .where(
        (reference) =>
            reference.enabled &&
            (reference.hasEncoding || reference.hasReencodeSource),
      )
      .toList();

  CharacterCenterDto _nativeCenter(CharacterPosition position) =>
      CharacterCenterDto(x: position.x, y: position.y);

  Future<List<String>> _nativeVibeData(
    GenerationSpec spec, {
    CancelToken? cancelToken,
  }) async {
    final values = <String>[];
    for (final reference in _enabledVibes(spec)) {
      // Prefer any cached/imported encoding for the active IE so already-paid
      // encodings are never re-charged.
      var encoded = reference.activeEncoding;
      if (encoded == null || encoded.isEmpty) {
        encoded = await _nativeEncodeVibeService.encode(
          NativeEncodeVibeRequestDto(
            image: await _vibeSourceBase64(reference),
            model: spec.model,
            informationExtracted: reference.informationExtracted,
          ),
          cancelToken: cancelToken,
        );
      }
      values.add(encoded);
    }
    return values;
  }

  Future<GatewayTextToImageRequestDto> _gatewayTextToImageDto(
    GenerationSpec spec,
  ) async {
    // Only already-encoded Vibe references can go through the OpenAI gateway:
    // new-api rejects uncached live Vibe encoding on the standard product.
    final vibes = BuiltInModels.supportsVibe(spec.model)
        ? _enabledVibes(
            spec,
          ).where((reference) => reference.hasEncoding).toList()
        : const <VibeReference>[];
    return GatewayTextToImageRequestDto(
      model: spec.model,
      prompt: spec.prompt,
      n: spec.sampleCount,
      width: spec.width,
      height: spec.height,
      size: spec.size,
      negativePrompt: spec.negativePrompt,
      steps: spec.steps,
      scale: spec.scale,
      cfgRescale: spec.cfgRescale,
      sampler: spec.sampler,
      noiseSchedule: spec.noiseSchedule,
      seed: spec.seed == 0 ? null : spec.seed,
      quality: spec.quality,
      ucPreset: spec.ucPreset.toString(),
      characters: _enabledCharacters(spec)
          .map(
            (character) => {
              'prompt': character.prompt,
              'uc': character.negativePrompt,
              'center': character.position.toJson(),
              'enabled': true,
            },
          )
          .toList(),
      encodedReferences: vibes
          .map((reference) => reference.activeEncoding ?? '')
          .where((value) => value.isNotEmpty)
          .toList(),
      referenceStrengths: vibes.map((reference) => reference.strength).toList(),
      informationExtractedValues: vibes
          .map((reference) => reference.informationExtracted)
          .toList(),
      responseFormat: 'b64_json',
    );
  }

  CancelToken _createCancelToken(String taskId) {
    _cancelTokens.remove(taskId)?.cancel('同一任务已开始新的请求。');
    final token = CancelToken();
    _cancelTokens[taskId] = token;
    return token;
  }

  Future<String> _vibeSourceBase64(VibeReference reference) async {
    final embedded = reference.sourceImageBase64;
    if (embedded != null && embedded.isNotEmpty) return embedded;
    return _readBase64(reference.imagePath, 'Vibe 参考图片');
  }

  Future<String> _readBase64(String? filePath, String label) async {
    final bytes = await _readFile(filePath, label);
    return base64Encode(bytes);
  }

  Future<String> _readProcessedCharacterReference(String? filePath) async {
    final bytes = await _readFile(filePath, '角色参考图片');
    return compute(CharacterReferencePreprocessor.process, bytes);
  }

  Future<Uint8List> _readFile(String? filePath, String label) async {
    if (filePath == null || filePath.trim().isEmpty) {
      throw ConfigurationException('缺少$label。');
    }
    final file = File(filePath);
    if (!await file.exists()) {
      throw ConfigurationException('$label不存在：$filePath');
    }
    return file.readAsBytes();
  }

  Future<GeneratedImage> _materializeImage(
    GeneratedImage image, {
    required CancelToken cancelToken,
  }) async {
    if (image.bytes != null) return image;
    final url = image.url;
    if (url == null) {
      throw const DataParsingException('图片响应既没有二进制内容也没有 URL。');
    }
    final response = await _downloadClient.get<List<int>>(
      url.toString(),
      options: Options(responseType: ResponseType.bytes),
      cancelToken: cancelToken,
    );
    return GeneratedImage(
      bytes: Uint8List.fromList(response.data ?? const []),
      mimeType:
          response.headers.value(Headers.contentTypeHeader) ?? image.mimeType,
      revisedPrompt: image.revisedPrompt,
    );
  }
}

/// A fully built native request, kept mode-safe so the caller either dispatches
/// it to the matching service or serialises it for the streaming endpoint.
sealed class _NativeRequest {
  const _NativeRequest();

  Map<String, Object?> toPayload();
}

class _NativeTextToImage extends _NativeRequest {
  const _NativeTextToImage(this.dto);

  final NativeTextToImageRequestDto dto;

  @override
  Map<String, Object?> toPayload() =>
      const NativeTextToImageRequestBuilder().build(dto);
}

class _NativeImageToImage extends _NativeRequest {
  const _NativeImageToImage(this.dto);

  final NativeImageToImageRequestDto dto;

  @override
  Map<String, Object?> toPayload() =>
      const NativeImageToImageRequestBuilder().build(dto);
}

class _NativeInpaint extends _NativeRequest {
  const _NativeInpaint(this.dto);

  final NativeInpaintRequestDto dto;

  @override
  Map<String, Object?> toPayload() =>
      const NativeInpaintRequestBuilder().build(dto);
}
