import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:wakelock_plus/wakelock_plus.dart';

import '../errors/app_exception.dart';
import '../storage/generation_image_store.dart';
import '../../domain/entities/generated_image.dart';
import '../../domain/entities/generation_task.dart';
import '../../domain/repositories/generation_history_repository.dart';
import '../../domain/repositories/generation_repository.dart';

class GenerationQueueState {
  const GenerationQueueState({
    required this.pendingCount,
    this.activeTask,
    this.cooldownUntil,
    this.previewImageBytes,
    this.previewStep,
  });

  const GenerationQueueState.idle()
    : pendingCount = 0,
      activeTask = null,
      cooldownUntil = null,
      previewImageBytes = null,
      previewStep = null;

  final int pendingCount;
  final GenerationTask? activeTask;
  final DateTime? cooldownUntil;
  final List<int>? previewImageBytes;
  final int? previewStep;

  bool get isRunning => activeTask != null;
}

class GenerationQueue {
  GenerationQueue({
    required GenerationRepository generationRepository,
    required GenerationHistoryRepository historyRepository,
    required GenerationImageStore imageStore,
    Future<void> Function(bool enabled)? wakeLockSetter,
    this.maxAutomaticRetries = 2,
    this.rateLimitCooldown = const Duration(seconds: 20),
  }) : _generationRepository = generationRepository,
       _historyRepository = historyRepository,
       _imageStore = imageStore,
       _wakeLockSetter = wakeLockSetter ?? _setWakeLock;

  final GenerationRepository _generationRepository;
  final GenerationHistoryRepository _historyRepository;
  final GenerationImageStore _imageStore;
  final int maxAutomaticRetries;
  final Duration rateLimitCooldown;
  final Future<void> Function(bool enabled) _wakeLockSetter;
  final Queue<String> _pendingIds = Queue<String>();
  final Set<String> _knownIds = {};
  final StreamController<GenerationQueueState> _stateController =
      StreamController<GenerationQueueState>.broadcast();
  final StreamController<GenerationTask> _taskController =
      StreamController<GenerationTask>.broadcast();

  GenerationTask? _activeTask;
  DateTime? _cooldownUntil;
  List<int>? _previewImageBytes;
  int? _previewStep;
  DateTime? _lastPreviewEmission;
  bool _isProcessing = false;
  bool _disposed = false;

  Stream<GenerationQueueState> get states => _stateController.stream;
  Stream<GenerationTask> get tasks => _taskController.stream;

  GenerationQueueState get state => GenerationQueueState(
    pendingCount: _pendingIds.length,
    activeTask: _activeTask,
    cooldownUntil: _cooldownUntil,
    previewImageBytes: _previewImageBytes,
    previewStep: _previewStep,
  );

  Future<void> initialize({bool resumeInterrupted = true}) async {
    final pending = await _historyRepository.pendingTasks();
    for (final task in pending) {
      if (!resumeInterrupted &&
          task.status == GenerationTaskStatus.interrupted) {
        continue;
      }
      final queued = task.copyWith(
        status: GenerationTaskStatus.queued,
        updatedAt: DateTime.now().toUtc(),
        clearError: true,
      );
      await _historyRepository.update(queued);
      _addPendingId(queued.id);
    }
    _emitState();
    unawaited(_process());
  }

  Future<GenerationTask> enqueue(GenerationTask task) async {
    if (_disposed) throw StateError('生成队列已释放。');
    final queued = task.copyWith(
      status: GenerationTaskStatus.queued,
      updatedAt: DateTime.now().toUtc(),
      clearError: true,
    );
    final existing = await _historyRepository.find(queued.id);
    if (existing == null) {
      await _historyRepository.save(queued);
    } else {
      await _historyRepository.update(queued);
    }
    _addPendingId(queued.id);
    _taskController.add(queued);
    _emitState();
    unawaited(_process());
    return queued;
  }

  Future<void> cancel(String taskId) async {
    if (_activeTask?.id == taskId) {
      await _generationRepository.cancel(taskId);
    }
    _pendingIds.remove(taskId);
    _knownIds.remove(taskId);
    final task = await _historyRepository.find(taskId);
    if (task != null && !task.isTerminal) {
      final cancelled = task.copyWith(
        status: GenerationTaskStatus.cancelled,
        updatedAt: DateTime.now().toUtc(),
        errorMessage: '用户取消了生成任务。',
      );
      await _historyRepository.update(cancelled);
      _taskController.add(cancelled);
    }
    _emitState();
  }

  Future<GenerationTask> retry(String taskId) async {
    final task = await _historyRepository.find(taskId);
    if (task == null) throw StateError('生成任务 $taskId 不存在。');
    return enqueue(
      task.copyWith(
        retryCount: task.retryCount + 1,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> _process() async {
    if (_isProcessing || _disposed) return;
    _isProcessing = true;
    try {
      while (_pendingIds.isNotEmpty && !_disposed) {
        await _waitForCooldown();
        final taskId = _pendingIds.removeFirst();
        _knownIds.remove(taskId);
        final persisted = await _historyRepository.find(taskId);
        if (persisted == null ||
            persisted.status == GenerationTaskStatus.cancelled) {
          continue;
        }
        await _runTask(persisted);
      }
    } finally {
      _activeTask = null;
      _isProcessing = false;
      _setWakeLockBestEffort(false);
      _emitState();
    }
  }

  Future<void> _runTask(GenerationTask task) async {
    var running = task.copyWith(
      status: GenerationTaskStatus.running,
      updatedAt: DateTime.now().toUtc(),
      clearError: true,
    );
    _activeTask = running;
    _previewImageBytes = null;
    _previewStep = null;
    _lastPreviewEmission = null;
    await _historyRepository.update(running);
    _taskController.add(running);
    _emitState();

    // Keeping the screen awake is an auxiliary feature and must never block
    // the actual generation request. Some Android vendors can leave the
    // platform-channel call pending, while a missing plugin can throw.
    _setWakeLockBestEffort(true);

    try {
      final result = running.spec.stream
          ? await _executeStream(running)
          : await _generationRepository.execute(running);
      if (result.images.isEmpty) {
        throw const DataParsingException('生成接口没有返回图片。');
      }
      final firstImage = result.images.first;
      final bytes = firstImage.bytes;
      if (bytes == null) {
        throw const DataParsingException('生成结果没有可保存的二进制图片。');
      }
      final stored = await _imageStore.save(
        taskId: running.id,
        bytes: bytes,
        extension: _extensionFor(firstImage.mimeType),
      );
      running = running.copyWith(
        status: GenerationTaskStatus.completed,
        updatedAt: DateTime.now().toUtc(),
        imagePath: stored.imagePath,
        thumbnailPath: stored.thumbnailPath,
        anlasCost: result.anlasCost,
        clearError: true,
      );
      await _historyRepository.update(running);
      _taskController.add(running);
    } catch (error) {
      final current = await _historyRepository.find(running.id);
      if (current?.status == GenerationTaskStatus.cancelled) return;
      if (_isRateLimited(error) && running.retryCount < maxAutomaticRetries) {
        _cooldownUntil = DateTime.now().toUtc().add(rateLimitCooldown);
        final retrying = running.copyWith(
          status: GenerationTaskStatus.queued,
          updatedAt: DateTime.now().toUtc(),
          retryCount: running.retryCount + 1,
          errorMessage: '请求过于频繁，将在冷却后自动重试。',
        );
        await _historyRepository.update(retrying);
        _addPendingId(retrying.id);
        _taskController.add(retrying);
        return;
      }
      final failed = running.copyWith(
        status: GenerationTaskStatus.failed,
        updatedAt: DateTime.now().toUtc(),
        errorMessage: _errorMessage(error),
      );
      await _historyRepository.update(failed);
      _taskController.add(failed);
    } finally {
      _activeTask = null;
      _previewImageBytes = null;
      _previewStep = null;
      _emitState();
    }
  }

  Future<GenerationExecutionResult> _executeStream(GenerationTask task) async {
    List<int>? finalBytes;
    await for (final preview in _generationRepository.stream(task)) {
      if (preview.isFinal) finalBytes = preview.imageBytes;
      final now = DateTime.now();
      final shouldEmit =
          preview.isFinal ||
          _lastPreviewEmission == null ||
          now.difference(_lastPreviewEmission!) >=
              const Duration(milliseconds: 650);
      if (!shouldEmit) continue;
      _previewImageBytes = preview.imageBytes;
      _previewStep = preview.step;
      _lastPreviewEmission = now;
      _emitState();
    }
    if (finalBytes == null) {
      throw const DataParsingException('流式生成结束但没有返回最终图片。');
    }
    return GenerationExecutionResult(
      images: [GeneratedImage(bytes: Uint8List.fromList(finalBytes))],
    );
  }

  Future<void> _waitForCooldown() async {
    final until = _cooldownUntil;
    if (until == null) return;
    final remaining = until.difference(DateTime.now().toUtc());
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    _cooldownUntil = null;
  }

  void _addPendingId(String taskId) {
    if (_knownIds.add(taskId)) _pendingIds.add(taskId);
  }

  void _setWakeLockBestEffort(bool enabled) {
    unawaited(_wakeLockSetter(enabled).catchError((_) {}));
  }

  static Future<void> _setWakeLock(bool enabled) =>
      enabled ? WakelockPlus.enable() : WakelockPlus.disable();

  bool _isRateLimited(Object error) =>
      error is NetworkException && error.statusCode == 429;

  String _errorMessage(Object error) =>
      error is AppException ? error.message : error.toString();

  String _extensionFor(String mimeType) => switch (mimeType.toLowerCase()) {
    'image/jpeg' => 'jpg',
    'image/webp' => 'webp',
    _ => 'png',
  };

  void _emitState() {
    if (!_stateController.isClosed) _stateController.add(state);
  }

  Future<void> dispose() async {
    _disposed = true;
    final active = _activeTask;
    if (active != null) await _generationRepository.cancel(active.id);
    _setWakeLockBestEffort(false);
    await _stateController.close();
    await _taskController.close();
  }
}
