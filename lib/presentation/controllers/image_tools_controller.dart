import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import '../../core/errors/error_message.dart';
import '../../core/network/backend_mode.dart';
import '../../core/storage/generation_image_store.dart';
import '../../core/storage/image_size_reader.dart';
import '../../core/storage/pixiv_image_cloaker.dart';
import '../../domain/entities/director_emotion.dart';
import '../../domain/entities/generation_task.dart';
import '../../domain/repositories/generation_history_repository.dart';
import '../../domain/repositories/image_tools_repository.dart';
import 'history_controller.dart';

class ImageToolsController extends ChangeNotifier {
  ImageToolsController({
    required ImageToolsRepository repository,
    required GenerationImageStore imageStore,
    required GenerationHistoryRepository historyRepository,
    required HistoryController historyController,
    PixivImageCloaker? cloaker,
    Uuid uuid = const Uuid(),
    this.onAnlasConsumed,
  }) : _repository = repository,
       _imageStore = imageStore,
       _historyRepository = historyRepository,
       _historyController = historyController,
       _cloaker = cloaker,
       _uuid = uuid;

  final ImageToolsRepository _repository;
  final GenerationImageStore _imageStore;
  final GenerationHistoryRepository _historyRepository;
  final HistoryController _historyController;
  final PixivImageCloaker? _cloaker;
  final Uuid _uuid;

  /// Invoked after a billed tool (upscale / director) completes so the caller
  /// can refresh the Anlas balance. Null in tests.
  final Future<dynamic> Function()? onAnlasConsumed;

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

  /// NAI metadata read from the source image; set by [extractMetadata].
  PixivImageMetadata? metadata;

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

  /// Compresses the source image. [mode] selects between aligning to the
  /// nearest 64-pixel grid or scaling down to fit within the Opus free
  /// tier (≤ 1,048,576 px). Pure client-side — no network, no Anlas.
  Future<void> compressImage(CompressMode mode) async {
    final path = sourceImagePath;
    if (path == null || path.isEmpty) {
      errorMessage = '请先选择源图片。';
      notifyListeners();
      return;
    }
    final srcW = width;
    final srcH = height;
    final (dstW, dstH) = _computeTargetSize(srcW, srcH, mode);
    if (dstW == srcW && dstH == srcH) {
      errorMessage = mode == CompressMode.align64
          ? '当前画幅已对齐 64 像素，无需压缩。'
          : '当前画幅已在免费范围内，无需压缩。';
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

  static (int, int) _computeTargetSize(int srcW, int srcH, CompressMode mode) {
    if (mode == CompressMode.align64) {
      return (_align64(srcW), _align64(srcH));
    }
    // freeTier: scale down to ≤ 1,048,576 px keeping aspect ratio,
    // then align to 64.
    const pixelCap = 1048576;
    final pixels = srcW * srcH;
    if (pixels <= pixelCap) {
      return (_align64(srcW), _align64(srcH));
    }
    final scale = sqrt(pixelCap / pixels);
    var newW = (srcW * scale).round();
    var newH = (srcH * scale).round();
    newW = _align64(newW);
    newH = _align64(newH);
    // Shrink one step if still over the cap after rounding.
    while (newW * newH > pixelCap) {
      if (newW >= newH) {
        newW -= 64;
      } else {
        newH -= 64;
      }
    }
    return (newW, newH);
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

  /// Reads NAI metadata from the source image (plain tEXt chunks + alpha-LSB
  /// gzip `stealth_pngcomp`). Pure client-side, no Anlas. The result is
  /// exposed on [metadata] for display.
  Future<void> extractMetadata() async {
    final cloaker = _cloaker;
    final path = sourceImagePath;
    if (cloaker == null) {
      errorMessage = '元数据提取不可用。';
      notifyListeners();
      return;
    }
    if (path == null || path.isEmpty) {
      errorMessage = '请先选择源图片。';
      notifyListeners();
      return;
    }
    isRunning = true;
    errorMessage = null;
    metadata = null;
    resultBytes = null;
    resultPath = null;
    anlasCost = null;
    notifyListeners();
    try {
      metadata = await cloaker.extractMetadata(path);
    } catch (error) {
      errorMessage = friendlyErrorMessage(error);
    } finally {
      isRunning = false;
      notifyListeners();
    }
  }

  /// Strips NAI metadata (PNG tEXt chunks + alpha LSB steganography) from the
  /// source image. Pure client-side — no network, no Anlas. The result lands
  /// in [resultBytes]/[resultPath] so the comparison card and gallery save
  /// work as usual.
  Future<void> stripMetadata() async {
    final cloaker = _cloaker;
    final path = sourceImagePath;
    if (cloaker == null) {
      errorMessage = '元数据剥离不可用。';
      notifyListeners();
      return;
    }
    if (path == null || path.isEmpty) {
      errorMessage = '请先选择源图片。';
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
      final strippedPath = await cloaker.cloak(path);
      final bytes = await File(strippedPath).readAsBytes();
      final stored = await _imageStore.save(
        taskId: 'cloak_${_uuid.v4()}',
        bytes: bytes,
        extension: 'png',
      );
      resultBytes = bytes;
      resultPath = stored.imagePath;
    } catch (error) {
      errorMessage = friendlyErrorMessage(error);
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
      final bytes = await _repository.materialize(result.image);
      final taskId = 'tool_${_uuid.v4()}';
      final stored = await _imageStore.save(
        taskId: taskId,
        bytes: bytes,
        extension: GenerationImageStore.extensionForMimeType(
          result.image.mimeType,
        ),
      );
      resultBytes = bytes;
      resultPath = stored.imagePath;
      anlasCost = result.anlasCost;
      // Save to generation history so the result appears in the gallery.
      final now = DateTime.now();
      final task = GenerationTask(
        id: taskId,
        spec: GenerationSpec(
          mode: GenerationMode.textToImage,
          backendMode: BackendMode.native,
          model: 'director-tool',
          prompt: _directorGuidance(),
          negativePrompt: '',
          width: width,
          height: height,
          steps: 0,
          scale: 5,
          cfgRescale: 0,
          sampler: 'k_euler_ancestral',
          noiseSchedule: 'karras',
          seed: 0,
        ),
        status: GenerationTaskStatus.completed,
        createdAt: now,
        updatedAt: now,
        imagePath: stored.imagePath,
        thumbnailPath: stored.thumbnailPath,
        anlasCost: anlasCost,
      );
      await _historyRepository.save(task);
      await _historyController.load();
      // Upscale and bg-removal always consume Anlas; other director tools may
      // too depending on size. Refresh unconditionally — the badge only
      // repaints when the balance actually changes.
      final cb = onAnlasConsumed;
      if (cb != null) unawaited(cb());
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
