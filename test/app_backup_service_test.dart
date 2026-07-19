import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_canvas/core/backup/app_backup_service.dart';
import 'package:novelai_canvas/core/network/backend_mode.dart';
import 'package:novelai_canvas/domain/entities/app_settings.dart';
import 'package:novelai_canvas/domain/entities/generation_task.dart';
import 'package:novelai_canvas/domain/entities/llm_assistant_settings.dart';
import 'package:novelai_canvas/domain/repositories/app_settings_repository.dart';
import 'package:novelai_canvas/domain/repositories/generation_history_repository.dart';
import 'package:novelai_canvas/domain/repositories/llm_assistant_settings_repository.dart';

void main() {
  test('备份包含设置、Prompt 与历史，但不包含任何安全凭据', () async {
    final history = _MemoryHistoryRepository([_task('task-1')]);
    final service = AppBackupService(
      appSettingsRepository: _MemoryAppSettingsRepository(
        const AppSettings(
          onboardingCompleted: true,
          backendMode: BackendMode.gateway,
          gatewayBaseUrl: 'https://gateway.example.com',
        ),
      ),
      llmSettingsRepository: _MemoryLlmSettingsRepository(
        const LlmAssistantSettings(
          model: 'text-model',
          prompts: PromptTemplateSet(keywordExtraction: '自定义提取'),
        ),
      ),
      historyRepository: history,
    );

    final encoded = jsonEncode(await service.createBackup());

    expect(encoded, contains(AppBackupService.format));
    expect(encoded, contains('自定义提取'));
    expect(encoded, contains('task-1'));
    expect(encoded, isNot(contains('api_key')));
    expect(encoded, isNot(contains('novelai_token')));
    expect(encoded, isNot(contains('gateway_api_key')));
    expect(encoded, isNot(contains('llm_api_key')));
  });

  test('导入备份恢复非敏感设置并按 ID 忽略重复历史', () async {
    final appRepository = _MemoryAppSettingsRepository(
      const AppSettings.initial(),
    );
    final llmRepository = _MemoryLlmSettingsRepository(
      const LlmAssistantSettings(),
    );
    final history = _MemoryHistoryRepository([_task('existing')]);
    final service = AppBackupService(
      appSettingsRepository: appRepository,
      llmSettingsRepository: llmRepository,
      historyRepository: history,
    );
    final source = jsonEncode({
      'format': AppBackupService.format,
      'format_version': 1,
      'app_settings': {
        'onboarding_completed': true,
        'backend_mode': 'gateway',
        'gateway_base_url': 'https://restored.example.com',
      },
      'llm_assistant_settings': {
        'provider_name': '自建 LLM',
        'base_url': 'https://llm.example.com',
        'model': 'assistant-model',
        'vision_model': '',
        'danbooru_base_url': '',
        'show_nsfw': false,
        'prompts': const PromptTemplateSet().toJson(),
      },
      'generation_history': [_task('existing').toJson(), _task('new').toJson()],
    });

    final result = await service.importFromJson(source);

    expect(result.importedHistoryCount, 2);
    expect(appRepository.value.backendMode, BackendMode.gateway);
    expect(appRepository.value.gatewayBaseUrl, 'https://restored.example.com');
    expect(llmRepository.value.model, 'assistant-model');
    expect(history.items.keys, containsAll(['existing', 'new']));
    expect(history.items.length, 2);
  });

  test('未知备份格式和未来版本会被拒绝', () async {
    final service = AppBackupService(
      appSettingsRepository: _MemoryAppSettingsRepository(
        const AppSettings.initial(),
      ),
      llmSettingsRepository: _MemoryLlmSettingsRepository(
        const LlmAssistantSettings(),
      ),
      historyRepository: _MemoryHistoryRepository(),
    );

    expect(
      () => service.importFromJson('{"format":"other","format_version":1}'),
      throwsFormatException,
    );
    expect(
      () => service.importFromJson(
        '{"format":"novelai-canvas-backup","format_version":99}',
      ),
      throwsFormatException,
    );
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
    status: GenerationTaskStatus.completed,
    createdAt: now,
    updatedAt: now,
    favorite: true,
  );
}

class _MemoryAppSettingsRepository implements AppSettingsRepository {
  _MemoryAppSettingsRepository(this.value);

  AppSettings value;

  @override
  Future<AppSettings> load() async => value;

  @override
  Future<void> save(AppSettings settings) async => value = settings;
}

class _MemoryLlmSettingsRepository implements LlmAssistantSettingsRepository {
  _MemoryLlmSettingsRepository(this.value);

  LlmAssistantSettings value;

  @override
  Future<LlmAssistantSettings> load() async => value;

  @override
  Future<void> save(LlmAssistantSettings settings) async => value = settings;
}

class _MemoryHistoryRepository implements GenerationHistoryRepository {
  _MemoryHistoryRepository([Iterable<GenerationTask> initial = const []]) {
    for (final task in initial) {
      items[task.id] = task;
    }
  }

  final Map<String, GenerationTask> items = {};

  @override
  Future<void> clear() async => items.clear();

  @override
  Future<void> delete(String id) async => items.remove(id);

  @override
  Future<GenerationTask?> find(String id) async => items[id];

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
  Future<void> initialize() async {}

  @override
  Future<List<GenerationTask>> list({
    int offset = 0,
    int limit = 50,
    String? query,
  }) async => items.values.skip(offset).take(limit).toList();

  @override
  Future<void> markRunningAsInterrupted() async {}

  @override
  Future<List<GenerationTask>> pendingTasks() async => const [];

  @override
  Future<GenerationTask> save(GenerationTask task) async {
    items[task.id] = task;
    return task;
  }

  @override
  Future<GenerationTask> toggleFavorite(String id) async {
    final updated = items[id]!.copyWith(favorite: !items[id]!.favorite);
    items[id] = updated;
    return updated;
  }

  @override
  Future<GenerationTask> update(GenerationTask task) async {
    items[task.id] = task;
    return task;
  }
}
