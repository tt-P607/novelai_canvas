import '../entities/generation_task.dart';

abstract interface class GenerationHistoryRepository {
  Future<void> initialize();
  Future<GenerationTask> save(GenerationTask task);
  Future<GenerationTask> update(GenerationTask task);
  Future<GenerationTask?> find(String id);
  Future<List<GenerationTask>> list({
    int offset = 0,
    int limit = 50,
    String? query,
  });
  Future<List<GenerationTask>> pendingTasks();
  Future<void> markRunningAsInterrupted();
  Future<void> delete(String id);
  Future<void> clear();
  Future<GenerationTask> toggleFavorite(String id);
}
