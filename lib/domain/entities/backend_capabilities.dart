import 'package:equatable/equatable.dart';

import '../../core/network/backend_mode.dart';

enum BackendFeature {
  textToImage,
  imageToImage,
  inpaint,
  edits,
  streaming,
  vibeTransfer,
  characterReference,
  multiCharacter,
  upscale,
  tagSuggestion,
  directorTools,
  userInfo,
}

class BackendCapabilities extends Equatable {
  const BackendCapabilities({required this.mode, required this.features});

  const BackendCapabilities.native()
    : mode = BackendMode.native,
      features = const {
        BackendFeature.textToImage,
        BackendFeature.imageToImage,
        BackendFeature.inpaint,
        BackendFeature.streaming,
        BackendFeature.vibeTransfer,
        BackendFeature.characterReference,
        BackendFeature.multiCharacter,
        BackendFeature.upscale,
        BackendFeature.tagSuggestion,
        BackendFeature.directorTools,
        BackendFeature.userInfo,
      };

  const BackendCapabilities.gateway()
    : mode = BackendMode.gateway,
      features = const {
        BackendFeature.textToImage,
        BackendFeature.imageToImage,
        BackendFeature.inpaint,
        BackendFeature.edits,
        BackendFeature.streaming,
        BackendFeature.vibeTransfer,
        BackendFeature.characterReference,
        BackendFeature.multiCharacter,
        BackendFeature.upscale,
        BackendFeature.tagSuggestion,
        BackendFeature.directorTools,
      };

  final BackendMode mode;
  final Set<BackendFeature> features;

  bool supports(BackendFeature feature) => features.contains(feature);

  @override
  List<Object?> get props => [mode, features];
}
