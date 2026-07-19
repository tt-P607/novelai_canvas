import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:novelai_canvas/core/errors/app_exception.dart';
import 'package:novelai_canvas/core/network/backend_mode.dart';
import 'package:novelai_canvas/core/queue/generation_queue.dart';
import 'package:novelai_canvas/core/storage/generation_image_store.dart';
import 'package:novelai_canvas/domain/entities/generated_image.dart';
import 'package:novelai_canvas/domain/entities/generation_task.dart';
import 'package:novelai_canvas/domain/repositories/generation_history_repository.dart';
import 'package:novelai_canvas/domain/repositories/generation_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('队列先持久化再串行执行并保存完成状态', () async {
    final history = _MemoryHistoryRepository();
    final generation = _FakeGenerationRepository();
    final imageStore = _MemoryImageStore();
    final queue = GenerationQueue(
      generationRepository: generation,
      historyRepository: history,
      imageStore: imageStore,
      wakeLockSetter: (_) async {},
    );

    final first = _task('first');
    final second = _task('second');
    await queue.enqueue(first);
    await queue.enqueue(second);
    await _waitFor(
      () =>
          history.items.values
              .where((task) => task.status == GenerationTaskStatus.completed)
              .length ==
          2,
    );

    expect(generation.executedIds, ['first', 'second']);
    expect(history.items['first']?.imagePath, '/memory/first.png');
    expect(history.items['second']?.imagePath, '/memory/second.png');
    await queue.dispose();
  });

  test('429 会进入冷却并自动重试', () async {
    final history = _MemoryHistoryRepository();
    final generation = _FakeGenerationRepository(rateLimitOnce: true);
    final queue = GenerationQueue(
      generationRepository: generation,
      historyRepository: history,
      imageStore: _MemoryImageStore(),
      rateLimitCooldown: const Duration(milliseconds: 5),
      wakeLockSetter: (_) async {},
    );

    await queue.enqueue(_task('retry'));
    await _waitFor(
      () => history.items['retry']?.status == GenerationTaskStatus.completed,
    );

    expect(generation.executedIds, ['retry', 'retry']);
    expect(history.items['retry']?.retryCount, 1);
    await queue.dispose();
  });
}

GenerationTask _task(String id) {
  final now = DateTime.utc(2026, 7, 19);
  return GenerationTask(
    id: id,
    spec: const GenerationSpec(
      mode: GenerationMode.textToImage,
      backendMode: BackendMode.native,
      model: 'nai-diffusion-4-5-full',
      prompt: '1girl',
      negativePrompt: '',
      width: 832,
      height: 1216,
      steps: 28,
      scale: 5,
      cfgRescale: 0,
      sampler: 'k_euler_ancestral',
      noiseSchedule: 'karras',
      seed: 1,
    ),
    status: GenerationTaskStatus.queued,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('等待队列状态超时。');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

class _FakeGenerationRepository implements GenerationRepository {
  _FakeGenerationRepository({this.rateLimitOnce = false});

  final bool rateLimitOnce;
  final List<String> executedIds = [];
  bool _limited = false;

  @override
  Future<GenerationExecutionResult> execute(GenerationTask task) async {
    executedIds.add(task.id);
    if (rateLimitOnce && !_limited) {
      _limited = true;
      throw const NetworkException('rate limited', statusCode: 429);
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return GenerationExecutionResult(
      images: [
        GeneratedImage(bytes: Uint8List.fromList([1, 2, 3])),
      ],
    );
  }

  @override
  Stream<GenerationPreview> stream(GenerationTask task) => const Stream.empty();

  @override
  Future<void> cancel(String taskId) async {}
}

class _MemoryImageStore extends GenerationImageStore {
  const _MemoryImageStore();

  @override
  Future<StoredGenerationImage> save({
    required String taskId,
    required Uint8List bytes,
    String extension = 'png',
  }) async => StoredGenerationImage(
    imagePath: '/memory/$taskId.$extension',
    thumbnailPath: '/memory/${taskId}_thumb.jpg',
  );
}

class _MemoryHistoryRepository implements GenerationHistoryRepository {
  final Map<String, GenerationTask> items = {};

  @override
  Future<void> clear() async => items.clear();

  @override
  Future<void> delete(String id) async => items.remove(id);

  @override
  Future<GenerationTask?> find(String id) async => items[id];

  @override
  Future<void> initialize() async {}

  @override
  Future<List<GenerationTask>> list({
    int offset = 0,
    int limit = 50,
    String? query,
  }) async => items.values.toList();

  @override
  Future<void> markRunningAsInterrupted() async {}

  @override
  Future<void> importAll(
    Iterable<GenerationTask> tasks, {
    bool replaceExisting = false,
  }) async {
    for (final task in tasks) {
      if (replaceExisting || !items.containsKey(task.id)) {
        items[task.id] = task;
      }
    }
  }

  @override
  Future<List<GenerationTask>> pendingTasks() async => items.values
      .where(
        (task) =>
            task.status == GenerationTaskStatus.queued ||
            task.status == GenerationTaskStatus.interrupted,
      )
      .toList();

  @override
  Future<GenerationTask> save(GenerationTask task) async {
    items[task.id] = task;
    return task;
  }

  @override
  Future<GenerationTask> toggleFavorite(String id) async {
    final task = items[id]!;
    return update(task.copyWith(favorite: !task.favorite));
  }

  @override
  Future<GenerationTask> update(GenerationTask task) async {
    items[task.id] = task;
    return task;
  }
}
