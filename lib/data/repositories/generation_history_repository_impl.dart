import 'package:sqflite/sqflite.dart';

import '../../domain/entities/generation_task.dart';
import '../../domain/repositories/generation_history_repository.dart';
import '../datasources/local/generation_database.dart';
import '../models/generation_task_model.dart';

class GenerationHistoryRepositoryImpl implements GenerationHistoryRepository {
  GenerationHistoryRepositoryImpl(this._database);

  final GenerationDatabase _database;

  @override
  Future<void> initialize() async {
    await _database.database;
    await markRunningAsInterrupted();
  }

  @override
  Future<GenerationTask> save(GenerationTask task) async {
    final db = await _database.database;
    await db.insert(
      GenerationTaskColumns.table,
      GenerationTaskModel(task).toDatabase(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return task;
  }

  @override
  Future<GenerationTask> update(GenerationTask task) async {
    final db = await _database.database;
    final count = await db.update(
      GenerationTaskColumns.table,
      GenerationTaskModel(task).toDatabase(),
      where: '${GenerationTaskColumns.id} = ?',
      whereArgs: [task.id],
    );
    if (count == 0) {
      throw StateError('生成任务 ${task.id} 不存在。');
    }
    return task;
  }

  @override
  Future<GenerationTask?> find(String id) async {
    final db = await _database.database;
    final rows = await db.query(
      GenerationTaskColumns.table,
      where: '${GenerationTaskColumns.id} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : GenerationTaskModel.fromDatabase(rows.first).task;
  }

  @override
  Future<List<GenerationTask>> list({
    int offset = 0,
    int limit = 50,
    String? query,
  }) async {
    final db = await _database.database;
    final normalizedQuery = query?.trim();
    final hasQuery = normalizedQuery != null && normalizedQuery.isNotEmpty;
    final rows = await db.query(
      GenerationTaskColumns.table,
      where: hasQuery
          ? '(${GenerationTaskColumns.prompt} LIKE ? OR '
                '${GenerationTaskColumns.negativePrompt} LIKE ? OR '
                '${GenerationTaskColumns.model} LIKE ?)'
          : null,
      whereArgs: hasQuery ? List.filled(3, '%$normalizedQuery%') : null,
      orderBy:
          '${GenerationTaskColumns.favorite} DESC, '
          '${GenerationTaskColumns.updatedAt} DESC',
      offset: offset,
      limit: limit,
    );
    return rows
        .map((row) => GenerationTaskModel.fromDatabase(row).task)
        .toList(growable: false);
  }

  @override
  Future<List<GenerationTask>> pendingTasks() async {
    final db = await _database.database;
    final rows = await db.query(
      GenerationTaskColumns.table,
      where: '${GenerationTaskColumns.status} IN (?, ?)',
      whereArgs: [
        GenerationTaskStatus.queued.name,
        GenerationTaskStatus.interrupted.name,
      ],
      orderBy: '${GenerationTaskColumns.createdAt} ASC',
    );
    return rows
        .map((row) => GenerationTaskModel.fromDatabase(row).task)
        .toList(growable: false);
  }

  @override
  Future<void> markRunningAsInterrupted() async {
    final db = await _database.database;
    await db.update(
      GenerationTaskColumns.table,
      {
        GenerationTaskColumns.status: GenerationTaskStatus.interrupted.name,
        GenerationTaskColumns.updatedAt: DateTime.now().millisecondsSinceEpoch,
        GenerationTaskColumns.errorMessage: '应用在任务执行期间退出，任务已标记为中断。',
      },
      where: '${GenerationTaskColumns.status} = ?',
      whereArgs: [GenerationTaskStatus.running.name],
    );
  }

  @override
  Future<void> importAll(
    Iterable<GenerationTask> tasks, {
    bool replaceExisting = false,
  }) async {
    final db = await _database.database;
    await db.transaction((transaction) async {
      final batch = transaction.batch();
      for (final task in tasks) {
        batch.insert(
          GenerationTaskColumns.table,
          GenerationTaskModel(task).toDatabase(),
          conflictAlgorithm: replaceExisting
              ? ConflictAlgorithm.replace
              : ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> delete(String id) async {
    final db = await _database.database;
    await db.delete(
      GenerationTaskColumns.table,
      where: '${GenerationTaskColumns.id} = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> clear() async {
    final db = await _database.database;
    await db.delete(GenerationTaskColumns.table);
  }

  @override
  Future<GenerationTask> toggleFavorite(String id) async {
    final task = await find(id);
    if (task == null) throw StateError('生成任务 $id 不存在。');
    return update(
      task.copyWith(favorite: !task.favorite, updatedAt: DateTime.now()),
    );
  }
}
