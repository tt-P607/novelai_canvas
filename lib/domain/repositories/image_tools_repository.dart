import 'dart:typed_data';

import '../entities/generated_image.dart';

/// Compression mode for the client-side image compressor.
enum CompressMode {
  /// Snap width/height to the nearest multiple of 64 without scaling.
  align64,

  /// Scale down (keeping aspect ratio) to ≤ 1,048,576 px, then align to 64.
  freeTier,
}

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
