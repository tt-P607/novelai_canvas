import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:novelai_canvas/core/network/backend_mode.dart';
import 'package:novelai_canvas/data/datasources/local/generation_database.dart';
import 'package:novelai_canvas/data/models/generation_task_model.dart';
import 'package:novelai_canvas/data/repositories/generation_history_repository_impl.dart';
import 'package:novelai_canvas/domain/entities/generation_task.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDirectory;
  late GenerationDatabase database;
  late GenerationHistoryRepositoryImpl repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('novelai_canvas_db_');
    database = GenerationDatabase(
      factory: databaseFactoryFfi,
      databasePath: '${tempDirectory.path}/history.db',
    );
    repository = GenerationHistoryRepositoryImpl(database);
    await repository.initialize();
  });

  tearDown(() async {
    await database.close();
    await tempDirectory.delete(recursive: true);
  });

  test('生成参数快照遇到未知枚举时使用安全默认值', () {
    final spec = GenerationSpec.fromJson({
      'mode': 'futureMode',
      'backendMode': 'futureBackend',
      'prompt': '1girl',
    });

    expect(spec.mode, GenerationMode.textToImage);
    expect(spec.backendMode, BackendMode.native);
    expect(GenerationSpec.decode(spec.encode()), spec);
  });

  test('任务模型数据库往返保留完整参数与状态', () {
    final task = _task(status: GenerationTaskStatus.completed, favorite: true)
        .copyWith(
          imagePath: '/images/result.png',
          thumbnailPath: '/thumbnails/result.jpg',
          anlasCost: 12,
        );

    final restored = GenerationTaskModel.fromDatabase(
      GenerationTaskModel(task).toDatabase(),
    ).task;

    expect(restored, task);
  });

  test('历史仓库支持保存、搜索、收藏和删除', () async {
    final task = _task(
      status: GenerationTaskStatus.completed,
      imagePath: '/results/task-1.png',
    );
    await repository.save(task);

    expect(await repository.find(task.id), task);
    expect(await repository.list(query: 'nai-diffusion'), [task]);
    expect(await repository.list(query: '1girl'), [task]);

    final favorite = await repository.toggleFavorite(task.id);
    expect(favorite.favorite, isTrue);

    await repository.delete(task.id);
    expect(await repository.find(task.id), isNull);
  });

  test('收藏任务排在收藏组内按创建时间排序，且不刷新 updatedAt', () async {
    final older = _task(
      status: GenerationTaskStatus.completed,
      id: 'task-older',
      imagePath: '/results/older.png',
      favorite: true,
      timestamp: DateTime.utc(2026, 7, 19, 8),
    );
    final newer = _task(
      status: GenerationTaskStatus.completed,
      id: 'task-newer',
      imagePath: '/results/newer.png',
      favorite: true,
      timestamp: DateTime.utc(2026, 7, 20, 8),
    );
    final plain = _task(
      status: GenerationTaskStatus.completed,
      id: 'task-plain',
      imagePath: '/results/plain.png',
      timestamp: DateTime.utc(2026, 7, 21, 8),
    );
    // Preserve creation timestamps so the ordering is deterministic.
    await repository.save(older);
    await repository.save(newer);
    await repository.save(plain);

    final list = await repository.list(limit: 100);
    expect(list.map((t) => t.id).toList(), [
      // favourites first (newer created first in list), then plain
      'task-newer',
      'task-older',
      'task-plain',
    ]);

    final before = await repository.find('task-plain');
    final toggled = await repository.toggleFavorite('task-plain');
    expect(toggled.favorite, isTrue);
    // Favouriting must not touch updatedAt, so the timeline does not jump.
    expect(toggled.updatedAt, before!.updatedAt);

    final after = await repository.list(limit: 100);
    expect(after.map((t) => t.id).toList(), [
      'task-plain',
      'task-newer',
      'task-older',
    ]);
  });

  test('初始化会把遗留 running 任务标记为 interrupted', () async {
    final running = _task(status: GenerationTaskStatus.running);
    await repository.save(running);

    await repository.markRunningAsInterrupted();
    final recovered = await repository.find(running.id);

    expect(recovered?.status, GenerationTaskStatus.interrupted);
    expect(recovered?.errorMessage, contains('中断'));
    expect(await repository.pendingTasks(), hasLength(1));
  });
}

GenerationTask _task({
  String id = 'task-1',
  GenerationTaskStatus status = GenerationTaskStatus.queued,
  bool favorite = false,
  String? imagePath,
  DateTime? timestamp,
}) {
  final effectiveTimestamp = timestamp ?? DateTime.utc(2026, 7, 19, 8);
  return GenerationTask(
    id: id,
    spec: const GenerationSpec(
      mode: GenerationMode.textToImage,
      backendMode: BackendMode.native,
      model: 'nai-diffusion-4-5-full',
      prompt: '1girl, masterpiece',
      negativePrompt: 'lowres',
      width: 832,
      height: 1216,
      steps: 28,
      scale: 5,
      cfgRescale: 0,
      sampler: 'k_euler_ancestral',
      noiseSchedule: 'karras',
      seed: 42,
    ),
    status: status,
    createdAt: effectiveTimestamp,
    updatedAt: effectiveTimestamp,
    favorite: favorite,
    imagePath: imagePath,
  );
}
