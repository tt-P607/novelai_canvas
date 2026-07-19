import '../../domain/entities/generation_task.dart';

abstract final class GenerationTaskColumns {
  static const table = 'generation_tasks';
  static const id = 'id';
  static const specJson = 'spec_json';
  static const mode = 'mode';
  static const backendMode = 'backend_mode';
  static const model = 'model';
  static const prompt = 'prompt';
  static const negativePrompt = 'negative_prompt';
  static const status = 'status';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
  static const imagePath = 'image_path';
  static const thumbnailPath = 'thumbnail_path';
  static const errorMessage = 'error_message';
  static const anlasCost = 'anlas_cost';
  static const retryCount = 'retry_count';
  static const favorite = 'favorite';
}

class GenerationTaskModel {
  const GenerationTaskModel(this.task);

  final GenerationTask task;

  Map<String, Object?> toDatabase() => {
    GenerationTaskColumns.id: task.id,
    GenerationTaskColumns.specJson: task.spec.encode(),
    GenerationTaskColumns.mode: task.spec.mode.name,
    GenerationTaskColumns.backendMode: task.spec.backendMode.name,
    GenerationTaskColumns.model: task.spec.model,
    GenerationTaskColumns.prompt: task.spec.prompt,
    GenerationTaskColumns.negativePrompt: task.spec.negativePrompt,
    GenerationTaskColumns.status: task.status.name,
    GenerationTaskColumns.createdAt: task.createdAt
        .toUtc()
        .millisecondsSinceEpoch,
    GenerationTaskColumns.updatedAt: task.updatedAt
        .toUtc()
        .millisecondsSinceEpoch,
    GenerationTaskColumns.imagePath: task.imagePath,
    GenerationTaskColumns.thumbnailPath: task.thumbnailPath,
    GenerationTaskColumns.errorMessage: task.errorMessage,
    GenerationTaskColumns.anlasCost: task.anlasCost,
    GenerationTaskColumns.retryCount: task.retryCount,
    GenerationTaskColumns.favorite: task.favorite ? 1 : 0,
  };

  factory GenerationTaskModel.fromDatabase(Map<String, Object?> row) {
    final spec = GenerationSpec.decode(
      row[GenerationTaskColumns.specJson]?.toString() ?? '{}',
    );
    return GenerationTaskModel(
      GenerationTask(
        id: row[GenerationTaskColumns.id]?.toString() ?? '',
        spec: spec,
        status: _enumByName(
          GenerationTaskStatus.values,
          row[GenerationTaskColumns.status]?.toString(),
          GenerationTaskStatus.interrupted,
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (row[GenerationTaskColumns.createdAt] as num?)?.toInt() ?? 0,
          isUtc: true,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (row[GenerationTaskColumns.updatedAt] as num?)?.toInt() ?? 0,
          isUtc: true,
        ),
        imagePath: row[GenerationTaskColumns.imagePath]?.toString(),
        thumbnailPath: row[GenerationTaskColumns.thumbnailPath]?.toString(),
        errorMessage: row[GenerationTaskColumns.errorMessage]?.toString(),
        anlasCost: (row[GenerationTaskColumns.anlasCost] as num?)?.toInt(),
        retryCount:
            (row[GenerationTaskColumns.retryCount] as num?)?.toInt() ?? 0,
        favorite: row[GenerationTaskColumns.favorite] == 1,
      ),
    );
  }
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
