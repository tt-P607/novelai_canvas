import 'package:equatable/equatable.dart';

import 'generated_image.dart';

class ImageGenerationResult extends Equatable {
  const ImageGenerationResult({
    required this.images,
    this.createdAt,
    this.anlasCost,
    this.requestId,
  });

  final List<GeneratedImage> images;
  final DateTime? createdAt;
  final int? anlasCost;
  final String? requestId;

  @override
  List<Object?> get props => [images, createdAt, anlasCost, requestId];
}
