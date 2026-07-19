import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/queue/generation_queue.dart';
import '../../domain/entities/generation_task.dart';
import '../../domain/repositories/generation_history_repository.dart';

class HistoryController extends ChangeNotifier {
  HistoryController({
    required GenerationHistoryRepository repository,
    required GenerationQueue queue,
  }) : _repository = repository {
    _taskSubscription = queue.tasks.listen((_) => unawaited(load()));
  }

  final GenerationHistoryRepository _repository;
  late final StreamSubscription<GenerationTask> _taskSubscription;

  List<GenerationTask> tasks = const [];
  bool loading = false;
  String query = '';
  String? errorMessage;

  Future<void> load({String? query}) async {
    if (query != null) this.query = query;
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      tasks = await _repository.list(query: this.query);
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(String id) async {
    await _repository.toggleFavorite(id);
    await load();
  }

  Future<void> delete(String id) async {
    final task = await _repository.find(id);
    if (task != null) {
      await _deleteFile(task.imagePath);
      await _deleteFile(task.thumbnailPath);
    }
    await _repository.delete(id);
    await load();
  }

  Future<void> clear() async {
    for (final task in await _repository.list(limit: 10000)) {
      await _deleteFile(task.imagePath);
      await _deleteFile(task.thumbnailPath);
    }
    await _repository.clear();
    await load();
  }

  Future<void> _deleteFile(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  @override
  void dispose() {
    unawaited(_taskSubscription.cancel());
    super.dispose();
  }
}
