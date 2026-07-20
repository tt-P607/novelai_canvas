import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/network_error_mapper.dart';
import '../../core/storage/generation_image_store.dart';
import '../../domain/entities/tag_suggestion.dart';
import '../../domain/repositories/image_tools_repository.dart';

const directorEmotionPrompts = <String, String>{
  '中性': 'neutral',
  '开心': 'happy',
  '悲伤': 'sad',
  '生气': 'angry',
  '害怕': 'scared',
  '惊讶': 'surprised',
  '疲惫': 'tired',
  '兴奋': 'excited',
  '紧张': 'nervous',
  '思考': 'thinking',
  '困惑': 'confused',
  '害羞': 'shy',
  '厌恶': 'disgusted',
  '得意': 'smug',
  '无聊': 'bored',
  '大笑': 'laughing',
  '烦躁': 'irritated',
  '脸红': 'aroused',
  '尴尬': 'embarrassed',
  '担忧': 'worried',
  '爱意': 'love',
  '坚定': 'determined',
  '受伤': 'hurt',
  '俏皮': 'playful',
};

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
  String selectedEmotion = '中性';
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
      try {
        final decoded = img.decodeImage(await File(path).readAsBytes());
        if (decoded != null) {
          width = decoded.width;
          height = decoded.height;
        }
      } catch (_) {
        errorMessage = '无法读取图片尺寸。';
      }
    }
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

  void selectEmotion(String value) {
    selectedEmotion = value;
    notifyListeners();
  }

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
    final guidance = selectedTool == DirectorTool.emotion
        ? [
            directorEmotionPrompts[selectedEmotion] ?? 'neutral',
            prompt.trim(),
          ].where((value) => value.isNotEmpty).join(', ')
        : prompt.trim();
    return _repository.applyDirectorTool(
      tool: selectedTool,
      imagePath: path,
      width: width,
      height: height,
      prompt: guidance,
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

  Future<void> useResultAsSource() async {
    final path = resultPath;
    if (path == null || path.isEmpty) return;
    await setSourceImage(path);
  }

  String _requireImagePath() {
    final path = sourceImagePath;
    if (path == null || path.isEmpty) throw StateError('请先选择源图片。');
    return path;
  }

  String _friendlyError(Object error) {
    if (error is AppException) return error.message;
    if (error is DioException) {
      return NetworkErrorMapper.map(error).message;
    }
    return error.toString().replaceFirst('Bad state: ', '');
  }

  String _extensionFor(String mimeType) => switch (mimeType) {
    'image/jpeg' => 'jpg',
    'image/webp' => 'webp',
    _ => 'png',
  };
}
