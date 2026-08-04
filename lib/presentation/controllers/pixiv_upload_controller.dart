import 'package:flutter/foundation.dart';

import '../../core/queue/pixiv_upload_queue.dart';
import '../../domain/entities/pixiv_upload_task.dart';

class PixivUploadController extends ChangeNotifier {
  PixivUploadController(this._queue) {
    _queue.addListener(_relay);
  }

  final PixivUploadQueue _queue;

  List<PixivUploadTask> get tasks => _queue.tasks;
  bool get isPaused => _queue.isPaused;
  Duration? get cooldownRemaining => _queue.cooldownRemaining;

  void enqueue(PixivUploadTask task) => _queue.enqueue(task);
  void cancel(String id) => _queue.cancel(id);
  void remove(String id) => _queue.remove(id);
  void clearFinished() => _queue.clearFinished();
  void pause() => _queue.pause();
  void resume() => _queue.resume();

  void _relay() => notifyListeners();

  @override
  void dispose() {
    _queue.removeListener(_relay);
    super.dispose();
  }
}
