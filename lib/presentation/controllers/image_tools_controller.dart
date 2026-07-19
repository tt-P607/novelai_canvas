import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_exception.dart';
import '../../core/storage/generation_image_store.dart';
import '../../domain/entities/tag_suggestion.dart';
import '../../domain/repositories/image_tools_repository.dart';

class ImageToolsController extends ChangeNotifier {
  ImageToolsController({
    required ImageToolsRepository repository,
    required GenerationImageStore imageStore,
    Uuid uuid = const Uuid(),
  }) : _repository = repository,
       _imageStore = imageStore,
       _uuid = uuid;

  final ImageToolsRepository _repository;
  final GenerationImageStore _imageStore;
  final Uuid _uuid;

  String? sourceImagePath;
  int width = 1024;
  int height = 1024;
  DirectorTool selectedTool = DirectorTool.declutter;
  String prompt = '';
  int defry = 0;
  bool isRunning = false;
  String? errorMessage;
  Uint8List? resultBytes;
  String? resultPath;
  int? anlasCost;
  List<TagSuggestion> suggestions = const [];

  void setSourceImage(String? path) {
    sourceImagePath = path;
    resultBytes = null;
    resultPath = null;
    notifyListeners();
  }

  void updateSize({required int width, required int height}) {
    this.width = width;
    this.height = height;
    notifyListeners();
  }

  void selectTool(DirectorTool tool) {
    selectedTool = tool;
    notifyListeners();
  }

  void updatePrompt(String value) => prompt = value;

  void updateDefry(double value) {
    defry = value.round();
    notifyListeners();
  }

  Future<void> upscale() => _run(() async {
    final path = _requireImagePath();
    return _repository.upscale(imagePath: path, width: width, height: height);
  });

  Future<void> applyDirectorTool() => _run(() async {
    final path = _requireImagePath();
    if ({DirectorTool.colorize, DirectorTool.emotion}.contains(selectedTool) &&
        prompt.trim().isEmpty) {
      throw StateError('上色和表情工具需要填写提示词。');
    }
    return _repository.applyDirectorTool(
      tool: selectedTool,
      imagePath: path,
      width: width,
      height: height,
      prompt: prompt.trim(),
      defry: defry,
    );
  });

  Future<void> suggestTags({required String model}) async {
    if (prompt.trim().isEmpty) {
      errorMessage = '请输入用于标签建议的提示词。';
      notifyListeners();
      return;
    }
    isRunning = true;
    errorMessage = null;
    notifyListeners();
    try {
      suggestions = await _repository.suggestTags(
        prompt: prompt.trim(),
        model: model,
      );
    } catch (error) {
      errorMessage = _friendlyError(error);
    } finally {
      isRunning = false;
      notifyListeners();
    }
  }

  Future<void> _run(Future<ImageToolResult> Function() action) async {
    isRunning = true;
    errorMessage = null;
    resultBytes = null;
    resultPath = null;
    notifyListeners();
    try {
      final result = await action();
      final bytes = result.image.bytes!;
      final stored = await _imageStore.save(
        taskId: 'tool_${_uuid.v4()}',
        bytes: bytes,
        extension: _extensionFor(result.image.mimeType),
      );
      resultBytes = bytes;
      resultPath = stored.imagePath;
      anlasCost = result.anlasCost;
    } catch (error) {
      errorMessage = _friendlyError(error);
    } finally {
      isRunning = false;
      notifyListeners();
    }
  }

  String _requireImagePath() {
    final path = sourceImagePath;
    if (path == null || path.isEmpty) throw StateError('请先选择源图片。');
    return path;
  }

  String _friendlyError(Object error) {
    if (error is AppException) return error.message;
    return error.toString().replaceFirst('Bad state: ', '');
  }

  String _extensionFor(String mimeType) => switch (mimeType) {
    'image/jpeg' => 'jpg',
    'image/webp' => 'webp',
    _ => 'png',
  };
}
