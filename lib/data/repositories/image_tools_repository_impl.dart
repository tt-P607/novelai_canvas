import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/backend_mode.dart';
import '../../domain/entities/generated_image.dart';
import '../../domain/entities/image_generation_result.dart';
import '../../domain/entities/tag_suggestion.dart';
import '../../domain/repositories/image_tools_repository.dart';
import '../api/gateway/dto/gateway_director_request_dto.dart';
import '../api/gateway/dto/gateway_tag_suggestion_request_dto.dart';
import '../api/gateway/dto/gateway_upscale_request_dto.dart';
import '../api/gateway/services/gateway_director_services.dart';
import '../api/gateway/services/gateway_tag_suggestion_service.dart';
import '../api/gateway/services/gateway_upscale_service.dart';
import '../api/native/dto/native_director_request_dto.dart';
import '../api/native/dto/native_tag_suggestion_request_dto.dart';
import '../api/native/dto/native_upscale_request_dto.dart';
import '../api/native/services/native_director_service.dart';
import '../api/native/services/native_tag_suggestion_service.dart';
import '../api/native/services/native_upscale_service.dart';

class ImageToolsRepositoryImpl implements ImageToolsRepository {
  ImageToolsRepositoryImpl({
    required BackendMode Function() backendModeProvider,
    required NativeUpscaleService nativeUpscaleService,
    required NativeTagSuggestionService nativeTagSuggestionService,
    required NativeDirectorService nativeDirectorService,
    required GatewayUpscaleService gatewayUpscaleService,
    required GatewayTagSuggestionService gatewayTagSuggestionService,
    required GatewayDeclutterService gatewayDeclutterService,
    required GatewayBackgroundRemovalService gatewayBackgroundRemovalService,
    required GatewayLineartService gatewayLineartService,
    required GatewaySketchService gatewaySketchService,
    required GatewayColorizeService gatewayColorizeService,
    required GatewayEmotionService gatewayEmotionService,
    Dio? downloadClient,
  }) : _backendModeProvider = backendModeProvider,
       _nativeUpscaleService = nativeUpscaleService,
       _nativeTagSuggestionService = nativeTagSuggestionService,
       _nativeDirectorService = nativeDirectorService,
       _gatewayUpscaleService = gatewayUpscaleService,
       _gatewayTagSuggestionService = gatewayTagSuggestionService,
       _gatewayDirectorServices = {
         DirectorTool.declutter: gatewayDeclutterService,
         DirectorTool.backgroundRemoval: gatewayBackgroundRemovalService,
         DirectorTool.lineart: gatewayLineartService,
         DirectorTool.sketch: gatewaySketchService,
         DirectorTool.colorize: gatewayColorizeService,
         DirectorTool.emotion: gatewayEmotionService,
       },
       _downloadClient = downloadClient ?? Dio();

  final BackendMode Function() _backendModeProvider;
  final NativeUpscaleService _nativeUpscaleService;
  final NativeTagSuggestionService _nativeTagSuggestionService;
  final NativeDirectorService _nativeDirectorService;
  final GatewayUpscaleService _gatewayUpscaleService;
  final GatewayTagSuggestionService _gatewayTagSuggestionService;
  final Map<DirectorTool, GatewayDirectorEndpointService>
  _gatewayDirectorServices;
  final Dio _downloadClient;

  @override
  Future<ImageToolResult> upscale({
    required String imagePath,
    required int width,
    required int height,
  }) async {
    final image = await _readBase64(imagePath, '放大源图片');
    final result = switch (_backendModeProvider()) {
      BackendMode.native => await _nativeUpscaleService.upscale(
        NativeUpscaleRequestDto(image: image, width: width, height: height),
      ),
      BackendMode.gateway => await _gatewayUpscaleService.upscale(
        GatewayUpscaleRequestDto(
          image: image,
          width: width,
          height: height,
          responseFormat: 'b64_json',
        ),
      ),
    };
    return _result(result);
  }

  @override
  Future<List<TagSuggestion>> suggestTags({
    required String prompt,
    required String model,
  }) => switch (_backendModeProvider()) {
    BackendMode.native => _nativeTagSuggestionService.suggest(
      NativeTagSuggestionRequestDto(prompt: prompt, model: model),
    ),
    BackendMode.gateway => _gatewayTagSuggestionService.suggest(
      GatewayTagSuggestionRequestDto(prompt: prompt, model: model),
    ),
  };

  @override
  Future<ImageToolResult> applyDirectorTool({
    required DirectorTool tool,
    required String imagePath,
    required int width,
    required int height,
    String prompt = '',
    int defry = 0,
  }) async {
    final image = await _readBase64(imagePath, '导演工具源图片');
    final result = switch (_backendModeProvider()) {
      BackendMode.native => await _nativeDirectorService.augment(
        NativeDirectorRequestDto(
          tool: _nativeDirectorTool(tool),
          image: image,
          width: width,
          height: height,
          prompt: prompt,
          defry: defry,
        ),
      ),
      BackendMode.gateway => await _gatewayDirectorServices[tool]!.process(
        GatewayDirectorRequestDto(
          tool: _gatewayDirectorTool(tool),
          image: image,
          width: width,
          height: height,
          prompt: prompt.isEmpty ? null : prompt,
          defry: defry,
          responseFormat: 'b64_json',
        ),
      ),
    };
    return _result(result);
  }

  @override
  Future<Uint8List> materialize(GeneratedImage image) async {
    final inline = image.bytes;
    if (inline != null) return inline;
    final url = image.url;
    if (url == null) throw const DataParsingException('工具响应缺少图片内容。');
    final response = await _downloadClient.get<List<int>>(
      url.toString(),
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const []);
  }

  Future<ImageToolResult> _result(ImageGenerationResult result) async {
    if (result.images.isEmpty) {
      throw const DataParsingException('工具响应没有返回图片。');
    }
    final image = result.images.first;
    return ImageToolResult(
      image: GeneratedImage(
        bytes: await materialize(image),
        mimeType: image.mimeType,
        revisedPrompt: image.revisedPrompt,
      ),
      anlasCost: result.anlasCost,
    );
  }

  Future<String> _readBase64(String imagePath, String label) async {
    if (imagePath.trim().isEmpty) throw ConfigurationException('缺少$label。');
    final file = File(imagePath);
    if (!await file.exists()) throw ConfigurationException('$label不存在。');
    return base64Encode(await file.readAsBytes());
  }

  NativeDirectorTool _nativeDirectorTool(DirectorTool tool) => switch (tool) {
    DirectorTool.declutter => NativeDirectorTool.declutter,
    DirectorTool.backgroundRemoval => NativeDirectorTool.backgroundRemoval,
    DirectorTool.lineart => NativeDirectorTool.lineart,
    DirectorTool.sketch => NativeDirectorTool.sketch,
    DirectorTool.colorize => NativeDirectorTool.colorize,
    DirectorTool.emotion => NativeDirectorTool.emotion,
  };

  GatewayDirectorTool _gatewayDirectorTool(DirectorTool tool) => switch (tool) {
    DirectorTool.declutter => GatewayDirectorTool.declutter,
    DirectorTool.backgroundRemoval => GatewayDirectorTool.backgroundRemoval,
    DirectorTool.lineart => GatewayDirectorTool.lineart,
    DirectorTool.sketch => GatewayDirectorTool.sketch,
    DirectorTool.colorize => GatewayDirectorTool.colorize,
    DirectorTool.emotion => GatewayDirectorTool.emotion,
  };
}
