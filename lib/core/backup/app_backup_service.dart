import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/entities/generation_task.dart';
import '../../domain/entities/llm_assistant_settings.dart';
import '../../domain/repositories/app_settings_repository.dart';
import '../../domain/repositories/generation_history_repository.dart';
import '../../domain/repositories/llm_assistant_settings_repository.dart';

class BackupImportResult {
  const BackupImportResult({required this.importedHistoryCount});

  final int importedHistoryCount;
}

class AppBackupService {
  AppBackupService({
    required AppSettingsRepository appSettingsRepository,
    required LlmAssistantSettingsRepository llmSettingsRepository,
    required GenerationHistoryRepository historyRepository,
  }) : _appSettingsRepository = appSettingsRepository,
       _llmSettingsRepository = llmSettingsRepository,
       _historyRepository = historyRepository;

  static const format = 'novelai-canvas-backup';
  static const formatVersion = 1;

  final AppSettingsRepository _appSettingsRepository;
  final LlmAssistantSettingsRepository _llmSettingsRepository;
  final GenerationHistoryRepository _historyRepository;

  Future<AppSettings> loadAppSettings() => _appSettingsRepository.load();

  Future<LlmAssistantSettings> loadLlmSettings() =>
      _llmSettingsRepository.load();

  Future<Map<String, Object?>> createBackup() async {
    final appSettings = await _appSettingsRepository.load();
    final llmSettings = await _llmSettingsRepository.load();
    final history = await _historyRepository.list(limit: 100000);
    return {
      'format': format,
      'format_version': formatVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'contains_sensitive_credentials': false,
      'app_settings': appSettings.toJson(),
      'llm_assistant_settings': llmSettings.toJson(),
      'generation_history': history.map((task) => task.toJson()).toList(),
    };
  }

  Future<String> exportToFile({String? targetPath}) async {
    final backup = await createBackup();
    final path = targetPath ?? await _defaultExportPath();
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(backup),
      flush: true,
    );
    return file.path;
  }

  Future<BackupImportResult> importFromFile(
    String path, {
    bool replaceExistingHistory = false,
  }) async {
    final source = await File(path).readAsString();
    return importFromJson(
      source,
      replaceExistingHistory: replaceExistingHistory,
    );
  }

  Future<BackupImportResult> importFromJson(
    String source, {
    bool replaceExistingHistory = false,
  }) async {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('备份文件根节点必须是 JSON 对象。');
    }
    final backup = Map<String, Object?>.from(decoded);
    if (backup['format'] != format) {
      throw const FormatException('这不是 NovelAI Canvas 备份文件。');
    }
    final version = (backup['format_version'] as num?)?.toInt();
    if (version == null || version < 1 || version > formatVersion) {
      throw FormatException('不支持的备份格式版本：$version。');
    }

    final appSettingsJson = backup['app_settings'];
    if (appSettingsJson is Map) {
      final imported = AppSettings.fromJson(
        Map<String, Object?>.from(appSettingsJson),
      ).copyWith(onboardingCompleted: true);
      await _appSettingsRepository.save(imported);
    }

    final llmSettingsJson = backup['llm_assistant_settings'];
    if (llmSettingsJson is Map) {
      await _llmSettingsRepository.save(
        LlmAssistantSettings.fromJson(
          Map<String, Object?>.from(llmSettingsJson),
        ),
      );
    }

    final tasks = <GenerationTask>[];
    final historyJson = backup['generation_history'];
    if (historyJson is List) {
      for (final item in historyJson.whereType<Map>()) {
        final task = GenerationTask.fromJson(Map<String, Object?>.from(item));
        if (task.id.trim().isNotEmpty) tasks.add(task);
      }
    }
    await _historyRepository.importAll(
      tasks,
      replaceExisting: replaceExistingHistory,
    );
    return BackupImportResult(importedHistoryCount: tasks.length);
  }

  Future<String> _defaultExportPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    return '${directory.path}${Platform.pathSeparator}NovelAICanvas-$timestamp.json';
  }
}
