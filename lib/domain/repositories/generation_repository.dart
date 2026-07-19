import '../entities/generated_image.dart';
import '../entities/generation_task.dart';

abstract interface class GenerationRepository {
  Future<GenerationExecutionResult> execute(GenerationTask task);
  Stream<GenerationPreview> stream(GenerationTask task);
  Future<void> cancel(String taskId);
}

class GenerationExecutionResult {
  const GenerationExecutionResult({required this.images, this.anlasCost});
  final List<GeneratedImage> images;
  final int? anlasCost;
}

class GenerationPreview {
  const GenerationPreview({
    required this.taskId,
    required this.step,
    required this.isFinal,
    required this.imageBytes,
  });
  final String taskId;
  final int step;
  final bool isFinal;
  final List<int> imageBytes;
}
