import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import '../../core/errors/error_message.dart';
import '../../core/storage/generation_image_store.dart';
import '../../domain/entities/director_emotion.dart';
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
  DirectorEmotion selectedEmotion = DirectorEmotion.neutral;
  int defry = 0;
  bool isRunning = false;
  String? errorMessage;
  Uint8List? resultBytes;
  String? resultPath;
  int? anlasCost;
  List<TagSuggestion> suggestions = const [];

  Future<void> setSourceImage(String? path) async {
    sourceImagePath = path;
    resultBytes = null;
    resultPath = null;
    if (path != null && path.isNotEmpty) {
      final size = await _readImageSize(path);
      if (size == null) {
        errorMessage = '无法读取图片尺寸。';
      } else {
        width = size.$1;
        height = size.$2;
      }
    }
    notifyListeners();
  }

  void selectTool(DirectorTool tool) {
    selectedTool = tool;
    notifyListeners();
  }

  void updatePrompt(String value) => prompt = value;

  void selectEmotion(DirectorEmotion value) {
    selectedEmotion = value;
    notifyListeners();
  }

  void updateDefry(double value) {
    defry = value.round();
    notifyListeners();
  }

  Future<void> upscale() => _run(
    () => _repository.upscale(
      imagePath: _requireImagePath(),
      width: width,
      height: height,
    ),
  );

  Future<void> applyDirectorTool() => _run(
    () => _repository.applyDirectorTool(
      tool: selectedTool,
      imagePath: _requireImagePath(),
      width: width,
      height: height,
      prompt: _directorGuidance(),
      defry: defry,
    ),
  );

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
      errorMessage = friendlyErrorMessage(error);
    } finally {
      isRunning = false;
      notifyListeners();
    }
  }

  Future<void> useResultAsSource() async {
    final path = resultPath;
    if (path == null || path.isEmpty) return;
    await setSourceImage(path);
  }

  /// The emotion tool combines the selected preset with an optional free-form
  /// addition; every other guided tool only sends the raw prompt.
  String _directorGuidance() {
    final addition = prompt.trim();
    if (selectedTool != DirectorTool.emotion) return addition;
    return [
      selectedEmotion.value,
      addition,
    ].where((value) => value.isNotEmpty).join(', ');
  }

  Future<void> _run(Future<ImageToolResult> Function() action) async {
    isRunning = true;
    errorMessage = null;
    resultBytes = null;
    resultPath = null;
    notifyListeners();
    try {
      final result = await action();
      final bytes = await _repository.materialize(result.image);
      final stored = await _imageStore.save(
        taskId: 'tool_${_uuid.v4()}',
        bytes: bytes,
        extension: GenerationImageStore.extensionForMimeType(
          result.image.mimeType,
        ),
      );
      resultBytes = bytes;
      resultPath = stored.imagePath;
      anlasCost = result.anlasCost;
    } catch (error) {
      errorMessage = friendlyErrorMessage(error);
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
}

/// Decoding runs off the UI isolate because large PNGs block the main thread
/// long enough to drop frames.
Future<(int, int)?> _readImageSize(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    return compute(_decodeSize, bytes);
  } catch (_) {
    return null;
  }
}

(int, int)? _decodeSize(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  return (decoded.width, decoded.height);
}
