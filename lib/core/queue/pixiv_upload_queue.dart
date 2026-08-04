import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../data/api/pixiv/pixiv_api_service.dart';
import '../../domain/repositories/pixiv_settings_repository.dart';
import '../../domain/repositories/pixiv_upload_repository.dart';
import '../storage/pixiv_image_cloaker.dart';
import '../../domain/entities/pixiv_upload_task.dart';

/// Serial upload queue for Pixiv illustrations.
///
/// Processes one task at a time. After a successful upload it waits
/// `cooldownMinutes ±5` minutes (random jitter) before marking the task as
/// completed, to avoid rate-limiting. State is in-memory only — process exit
/// clears all pending tasks.
class PixivUploadQueue extends ChangeNotifier {
  PixivUploadQueue({
    required PixivUploadRepository uploadRepository,
    required PixivSettingsRepository settingsRepository,
    required PixivImageCloaker cloaker,
  }) : _uploadRepository = uploadRepository,
       _settingsRepository = settingsRepository,
       _cloaker = cloaker;

  final PixivUploadRepository _uploadRepository;
  final PixivSettingsRepository _settingsRepository;
  final PixivImageCloaker _cloaker;
  final Random _random = Random();

  final List<PixivUploadTask> _tasks = [];
  bool _processing = false;
  bool _paused = false;
  Timer? _cooldownTimer;
  Duration? _cooldownRemaining;
  Timer? _cooldownTick;

  List<PixivUploadTask> get tasks => List.unmodifiable(_tasks);
  bool get isPaused => _paused;
  Duration? get cooldownRemaining => _cooldownRemaining;

  void enqueue(PixivUploadTask task) {
    _tasks.add(task);
    notifyListeners();
    _maybeStart();
  }

  void cancel(String id) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    final cur = _tasks[i];
    if (cur.status == PixivUploadStatus.pending) {
      _tasks[i] = cur.copyWith(status: PixivUploadStatus.canceled);
      notifyListeners();
    } else if (cur.status == PixivUploadStatus.completed ||
        cur.status == PixivUploadStatus.failed ||
        cur.status == PixivUploadStatus.canceled) {
      _tasks.removeAt(i);
      notifyListeners();
    }
  }

  void remove(String id) {
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  void clearFinished() {
    _tasks.removeWhere(
      (t) =>
          t.status == PixivUploadStatus.completed ||
          t.status == PixivUploadStatus.canceled ||
          t.status == PixivUploadStatus.failed,
    );
    notifyListeners();
  }

  void pause() {
    _paused = true;
    notifyListeners();
  }

  void resume() {
    _paused = false;
    notifyListeners();
    _maybeStart();
  }

  void _maybeStart() {
    if (_processing || _paused) return;
    final next = _tasks.firstWhere(
      (t) => t.status == PixivUploadStatus.pending,
      orElse: () => _sentinelValue,
    );
    if (identical(next, _sentinelValue)) return;
    _processing = true;
    _runOne(next.id).whenComplete(() {
      _processing = false;
      _maybeStart();
    });
  }

  static final _sentinelValue = PixivUploadTask(
    id: '__empty__',
    imagePaths: const [],
    title: '',
    caption: '',
    tags: const [],
    xRestrict: PixivXRestrict.general,
    aiType: PixivAiType.aiGenerated,
    restrict: PixivRestrict.public,
    allowComment: false,
    allowTagEdit: false,
    sexual: false,
    attributes: PixivAttributes(),
    ratings: PixivRatings(),
    titleTranslationEn: '',
    captionTranslationEn: '',
    responseAutoAccept: false,
    original: false,
    stripMetadata: false,
    createdAt: DateTime(0),
  );

  Future<void> _runOne(String id) async {
    final settings = await _settingsRepository.load();

    _update(
      id,
      (t) => t.copyWith(status: PixivUploadStatus.uploading, clearError: true),
    );

    final current = _findById(id);
    if (current == null) return;

    var imagesToUpload = current.imagePaths;
    if (current.stripMetadata) {
      try {
        final cloaked = <String>[];
        for (final path in current.imagePaths) {
          cloaked.add(await _cloaker.cloak(path));
        }
        imagesToUpload = cloaked;
      } catch (e) {
        debugPrint('[PixivQueue] 隐写擦除失败: $e');
        _update(
          id,
          (t) =>
              t.copyWith(status: PixivUploadStatus.failed, error: '隐写擦除失败: $e'),
        );
        return;
      }
    }

    try {
      final illustId = await _uploadRepository.upload(
        settings: settings,
        task: current.copyWith(imagePaths: imagesToUpload),
      );
      _update(
        id,
        (t) => t.copyWith(
          status: PixivUploadStatus.cooldown,
          illustId: illustId,
          completedAt: DateTime.now(),
          clearError: true,
        ),
      );
      await _doCooldown(id, settings.cooldownMinutes);
      _update(
        id,
        (t) => t.copyWith(
          status: PixivUploadStatus.completed,
          clearCooldown: true,
        ),
      );
    } on PixivCooldownException catch (e) {
      _update(
        id,
        (t) => t.copyWith(
          status: PixivUploadStatus.failed,
          error: '投稿冷却：${e.message}',
        ),
      );
    } on PixivAuthException catch (e) {
      _update(
        id,
        (t) => t.copyWith(
          status: PixivUploadStatus.failed,
          error: '鉴权失败：${e.message}',
        ),
      );
    } on PixivUploadException catch (e) {
      _update(
        id,
        (t) => t.copyWith(status: PixivUploadStatus.failed, error: e.message),
      );
    } catch (e) {
      _update(
        id,
        (t) => t.copyWith(status: PixivUploadStatus.failed, error: '上传异常: $e'),
      );
    }
  }

  Future<void> _doCooldown(String id, int minutes) async {
    final base = minutes.clamp(1, 999);
    final low = (base - 5).clamp(1, 999);
    final high = (base + 5).clamp(low + 1, 999 * 2);
    final seconds = (low * 60) + _random.nextInt((high - low) * 60 + 1);
    final until = DateTime.now().add(Duration(seconds: seconds));
    _update(id, (t) => t.copyWith(cooldownUntil: until));

    _cooldownRemaining = Duration(seconds: seconds);
    _cooldownTick?.cancel();
    _cooldownTick = Timer.periodic(const Duration(seconds: 1), (_) {
      final remain = until.difference(DateTime.now());
      if (remain.isNegative) {
        _cooldownRemaining = null;
        _cooldownTick?.cancel();
      } else {
        _cooldownRemaining = remain;
      }
      notifyListeners();
    });

    final completer = Completer<void>();
    _cooldownTimer = Timer(Duration(seconds: seconds), () {
      _cooldownTick?.cancel();
      _cooldownRemaining = null;
      completer.complete();
    });
    await completer.future;
  }

  PixivUploadTask? _findById(String id) {
    final i = _tasks.indexWhere((t) => t.id == id);
    return i < 0 ? null : _tasks[i];
  }

  void _update(String id, PixivUploadTask Function(PixivUploadTask) f) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    _tasks[i] = f(_tasks[i]);
    notifyListeners();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _cooldownTick?.cancel();
    super.dispose();
  }
}
