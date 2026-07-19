import 'dart:typed_data';

import '../entities/generated_image.dart';
import '../entities/tag_suggestion.dart';

enum DirectorTool {
  declutter,
  backgroundRemoval,
  lineart,
  sketch,
  colorize,
  emotion,
}

class ImageToolResult {
  const ImageToolResult({required this.image, this.anlasCost, this.savedPath});

  final GeneratedImage image;
  final int? anlasCost;
  final String? savedPath;
}

abstract interface class ImageToolsRepository {
  Future<ImageToolResult> upscale({
    required String imagePath,
    required int width,
    required int height,
  });

  Future<List<TagSuggestion>> suggestTags({
    required String prompt,
    required String model,
  });

  Future<ImageToolResult> applyDirectorTool({
    required DirectorTool tool,
    required String imagePath,
    required int width,
    required int height,
    String prompt = '',
    int defry = 0,
  });

  Future<Uint8List> materialize(GeneratedImage image);
}
