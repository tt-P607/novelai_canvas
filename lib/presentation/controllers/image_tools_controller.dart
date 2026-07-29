import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import '../../core/errors/error_message.dart';
import '../../core/storage/generation_image_store.dart';
import '../../core/storage/image_size_reader.dart';
import '../../domain/entities/director_emotion.dart';
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

  Future<void> setSourceImage(String? path) async {
    sourceImagePath = path;
    resultBytes = null;
    resultPath = null;
    if (path != null && path.isNotEmpty) {
      final size = await readImageSize(path);
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

  /// Compresses the source image to a 64-aligned target size using LANCZOS
  /// resampling. Pure client-side — no network call, no Anlas cost.
  Future<void> compressImage() async {
    final path = sourceImagePath;
    if (path == null || path.isEmpty) {
      errorMessage = '请先选择源图片。';
      notifyListeners();
      return;
    }
    final srcW = width;
    final srcH = height;
    final dstW = _align64(srcW);
    final dstH = _align64(srcH);
    if (dstW == srcW && dstH == srcH) {
      errorMessage = '当前画幅已对齐 64 像素，无需压缩。';
      notifyListeners();
      return;
    }
    isRunning = true;
    errorMessage = null;
    resultBytes = null;
    resultPath = null;
    anlasCost = null;
    notifyListeners();
    try {
      final sourceBytes = await File(path).readAsBytes();
      final result = await compute(_resizeImage, (sourceBytes, dstW, dstH));
      final stored = await _imageStore.save(
        taskId: 'compress_${_uuid.v4()}',
        bytes: result,
        extension: 'png',
      );
      resultBytes = result;
      resultPath = stored.imagePath;
    } catch (error) {
      errorMessage = friendlyErrorMessage(error);
    } finally {
      isRunning = false;
      notifyListeners();
    }
  }

  static int _align64(int value) =>
      ((value.clamp(64, 1600) + 32) ~/ 64 * 64).clamp(64, 1600);

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

Uint8List _resizeImage((Uint8List, int, int) args) {
  final (sourceBytes, dstW, dstH) = args;
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) throw FormatException('无法解码图片。');
  final resized = img.copyResize(
    decoded,
    width: dstW,
    height: dstH,
    interpolation: img.Interpolation.cubic,
  );
  return Uint8List.fromList(img.encodePng(resized));
}
