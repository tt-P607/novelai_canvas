import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../../models/generation_task_model.dart';

class GenerationDatabase {
  GenerationDatabase({this.factory, this.databasePath});

  static const schemaVersion = 1;
  static const fileName = 'novelai_canvas.db';

  final DatabaseFactory? factory;
  final String? databasePath;
  Database? _database;

  Future<Database> get database async {
    final current = _database;
    if (current != null) return current;

    final resolvedFactory = factory ?? databaseFactory;
    final resolvedPath =
        databasePath ?? path.join(await getDatabasesPath(), fileName);
    return _database = await resolvedFactory.openDatabase(
      resolvedPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _createSchema,
        onUpgrade: _upgradeSchema,
      ),
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  static Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${GenerationTaskColumns.table} (
        ${GenerationTaskColumns.id} TEXT PRIMARY KEY,
        ${GenerationTaskColumns.specJson} TEXT NOT NULL,
        ${GenerationTaskColumns.mode} TEXT NOT NULL,
        ${GenerationTaskColumns.backendMode} TEXT NOT NULL,
        ${GenerationTaskColumns.model} TEXT NOT NULL,
        ${GenerationTaskColumns.prompt} TEXT NOT NULL,
        ${GenerationTaskColumns.negativePrompt} TEXT NOT NULL DEFAULT '',
        ${GenerationTaskColumns.status} TEXT NOT NULL,
        ${GenerationTaskColumns.createdAt} INTEGER NOT NULL,
        ${GenerationTaskColumns.updatedAt} INTEGER NOT NULL,
        ${GenerationTaskColumns.imagePath} TEXT,
        ${GenerationTaskColumns.thumbnailPath} TEXT,
        ${GenerationTaskColumns.errorMessage} TEXT,
        ${GenerationTaskColumns.anlasCost} INTEGER,
        ${GenerationTaskColumns.retryCount} INTEGER NOT NULL DEFAULT 0,
        ${GenerationTaskColumns.favorite} INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_generation_tasks_updated_at
      ON ${GenerationTaskColumns.table} (${GenerationTaskColumns.updatedAt} DESC)
    ''');
    await db.execute('''
      CREATE INDEX idx_generation_tasks_status
      ON ${GenerationTaskColumns.table} (${GenerationTaskColumns.status})
    ''');
    await db.execute('''
      CREATE INDEX idx_generation_tasks_favorite
      ON ${GenerationTaskColumns.table} (${GenerationTaskColumns.favorite})
    ''');
  }

  static Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // 首版 schema 已保留显式迁移入口，后续只追加顺序迁移。
  }
}
