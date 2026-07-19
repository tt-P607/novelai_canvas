import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/backend_mode.dart';
import '../../domain/entities/generated_image.dart';
import '../../domain/entities/generation_task.dart';
import '../../domain/entities/image_generation_result.dart';
import '../../domain/repositories/generation_repository.dart';
import '../api/gateway/dto/gateway_generation_request_dto.dart';
import '../api/gateway/dto/gateway_image_to_image_request_dto.dart';
import '../api/gateway/dto/gateway_inpaint_request_dto.dart';
import '../api/gateway/services/gateway_generation_service.dart';
import '../api/gateway/services/gateway_image_to_image_service.dart';
import '../api/gateway/services/gateway_inpaint_service.dart';
import '../api/native/dto/native_generation_parameters_dto.dart';
import '../api/native/dto/native_image_to_image_request_dto.dart';
import '../api/native/dto/native_inpaint_request_dto.dart';
import '../api/native/dto/native_stream_dto.dart';
import '../api/native/dto/native_text_to_image_request_dto.dart';
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
    required GatewayGenerationService gatewayGenerationService,
    required GatewayImageToImageService gatewayImageToImageService,
    required GatewayInpaintService gatewayInpaintService,
    Dio? downloadClient,
  }) : _nativeTextToImageService = nativeTextToImageService,
       _nativeImageToImageService = nativeImageToImageService,
       _nativeInpaintService = nativeInpaintService,
       _nativeStreamService = nativeStreamService,
       _gatewayGenerationService = gatewayGenerationService,
       _gatewayImageToImageService = gatewayImageToImageService,
       _gatewayInpaintService = gatewayInpaintService,
       _downloadClient = downloadClient ?? Dio();

  final NativeTextToImageService _nativeTextToImageService;
  final NativeImageToImageService _nativeImageToImageService;
  final NativeInpaintService _nativeInpaintService;
  final NativeStreamService _nativeStreamService;
  final GatewayGenerationService _gatewayGenerationService;
  final GatewayImageToImageService _gatewayImageToImageService;
  final GatewayInpaintService _gatewayInpaintService;
  final Dio _downloadClient;
  final Map<String, CancelToken> _cancelTokens = {};

  @override
  Future<GenerationExecutionResult> execute(GenerationTask task) async {
    final cancelToken = _createCancelToken(task.id);
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
    if (task.spec.backendMode != BackendMode.native ||
        task.spec.mode != GenerationMode.textToImage) {
      throw const UnsupportedFeatureException('只有 NovelAI 原生文生图支持中间预览流。');
    }
    final cancelToken = _createCancelToken(task.id);
    try {
      final request = NativeStreamRequestDto(_nativeTextRequest(task.spec));
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
    } finally {
      _cancelTokens.remove(task.id);
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
    final spec = task.spec;
    return switch (spec.mode) {
      GenerationMode.textToImage => _nativeTextToImageService.generate(
        _nativeTextRequest(spec),
        cancelToken: cancelToken,
      ),
      GenerationMode.imageToImage => _nativeImageToImageService.generate(
        NativeImageToImageRequestDto(
          prompt: spec.prompt,
          model: spec.model,
          parameters: _nativeParameters(spec),
          image: await _readBase64(spec.sourceImagePath, '图生图源图片'),
          strength: spec.strength,
          noise: spec.noise,
        ),
        cancelToken: cancelToken,
      ),
      GenerationMode.inpaint => _nativeInpaintService.generate(
        NativeInpaintRequestDto(
          prompt: spec.prompt,
          model: spec.model,
          parameters: _nativeParameters(spec),
          image: await _readBase64(spec.sourceImagePath, '局部重绘源图片'),
          mask: await _readBase64(spec.maskImagePath, '局部重绘蒙版'),
          strength: spec.strength,
          noise: spec.noise,
        ),
        cancelToken: cancelToken,
      ),
    };
  }

  Future<ImageGenerationResult> _executeGateway(
    GenerationTask task,
    CancelToken cancelToken,
  ) async {
    final spec = task.spec;
    return switch (spec.mode) {
      GenerationMode.textToImage => _gatewayGenerationService.generate(
        GatewayGenerationRequestDto(
          model: spec.model,
          prompt: spec.prompt,
          size: spec.size,
          responseFormat: 'b64_json',
        ),
        cancelToken: cancelToken,
      ),
      GenerationMode.imageToImage => _gatewayImageToImageService.generate(
        GatewayImageToImageRequestDto(
          model: spec.model,
          prompt: spec.prompt,
          image: await _readDataUri(spec.sourceImagePath, '图生图源图片'),
          strength: spec.strength,
          addOriginalImage: spec.addOriginalImage,
          width: spec.width,
          height: spec.height,
          scale: spec.scale,
          cfgRescale: spec.cfgRescale,
          sampler: spec.sampler,
          noiseSchedule: spec.noiseSchedule,
          seed: spec.seed,
          negativePrompt: spec.negativePrompt,
          quality: spec.quality,
          ucPreset: spec.ucPreset,
          responseFormat: 'b64_json',
        ),
        cancelToken: cancelToken,
      ),
      GenerationMode.inpaint => _gatewayInpaintService.generate(
        GatewayInpaintRequestDto(
          model: spec.model,
          prompt: spec.prompt,
          image: await _readDataUri(spec.sourceImagePath, '局部重绘源图片'),
          mask: await _readDataUri(spec.maskImagePath, '局部重绘蒙版'),
          strength: spec.strength,
          addOriginalImage: spec.addOriginalImage,
          size: spec.size,
          scale: spec.scale,
          cfgRescale: spec.cfgRescale,
          sampler: spec.sampler,
          noiseSchedule: spec.noiseSchedule,
          seed: spec.seed,
          negativePrompt: spec.negativePrompt,
          quality: spec.quality,
          ucPreset: spec.ucPreset,
          responseFormat: 'b64_json',
        ),
        cancelToken: cancelToken,
      ),
    };
  }

  NativeTextToImageRequestDto _nativeTextRequest(GenerationSpec spec) =>
      NativeTextToImageRequestDto(
        prompt: spec.prompt,
        model: spec.model,
        parameters: _nativeParameters(spec),
      );

  NativeGenerationParametersDto _nativeParameters(GenerationSpec spec) =>
      NativeGenerationParametersDto(
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
      );

  CancelToken _createCancelToken(String taskId) {
    _cancelTokens.remove(taskId)?.cancel('同一任务已开始新的请求。');
    final token = CancelToken();
    _cancelTokens[taskId] = token;
    return token;
  }

  Future<String> _readBase64(String? filePath, String label) async {
    final bytes = await _readFile(filePath, label);
    return base64Encode(bytes);
  }

  Future<String> _readDataUri(String? filePath, String label) async {
    final bytes = await _readFile(filePath, label);
    final mimeType = _mimeTypeFor(filePath!);
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
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

  String _mimeTypeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/png';
  }
}
