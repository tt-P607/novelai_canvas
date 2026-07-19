class CharacterCenterDto {
  const CharacterCenterDto({required this.x, required this.y});

  final double x;
  final double y;

  Map<String, Object?> toJson() => {'x': x, 'y': y};
}

class CharacterPromptDto {
  const CharacterPromptDto({
    required this.prompt,
    required this.negativePrompt,
    required this.center,
    this.enabled = true,
  });

  final String prompt;
  final String negativePrompt;
  final CharacterCenterDto center;
  final bool enabled;

  Map<String, Object?> toJson() => {
    'prompt': prompt,
    'uc': negativePrompt,
    'center': center.toJson(),
    'enabled': enabled,
  };
}

class V4CharacterCaptionDto {
  const V4CharacterCaptionDto({required this.caption, required this.centers});

  final String caption;
  final List<CharacterCenterDto> centers;

  Map<String, Object?> toJson() => {
    'char_caption': caption,
    'centers': centers.map((center) => center.toJson()).toList(),
  };
}

class V4PromptDto {
  const V4PromptDto({
    required this.baseCaption,
    this.characterCaptions = const [],
    this.useCoords = false,
    this.useOrder = true,
    this.legacyUc,
  });

  final String baseCaption;
  final List<V4CharacterCaptionDto> characterCaptions;
  final bool useCoords;
  final bool useOrder;
  final bool? legacyUc;

  Map<String, Object?> toJson() => {
    'caption': {
      'base_caption': baseCaption,
      'char_captions': characterCaptions
          .map((caption) => caption.toJson())
          .toList(),
    },
    if (legacyUc == null) ...{
      'use_coords': useCoords,
      'use_order': useOrder,
    } else
      'legacy_uc': legacyUc,
  };
}

class DirectorReferenceDto {
  const DirectorReferenceDto({
    required this.image,
    required this.description,
    this.strength = 1,
    this.fidelity = 0.5,
    this.informationExtracted = 1,
  });

  final String image;
  final String description;
  final double strength;
  final double fidelity;
  final double informationExtracted;
}

class NativeGenerationParametersDto {
  const NativeGenerationParametersDto({
    required this.width,
    required this.height,
    required this.seed,
    required this.negativePrompt,
    this.steps = 28,
    this.scale = 5,
    this.sampler = 'k_euler_ancestral',
    this.sampleCount = 1,
    this.noiseSchedule = 'karras',
    this.cfgRescale = 0,
    this.qualityToggle = true,
    this.ucPreset = 1,
    this.v4Prompt,
    this.v4NegativePrompt,
    this.characterPrompts = const [],
    this.vibeData = const [],
    this.vibeStrengths = const [],
    this.vibeInformationExtracted = const [],
    this.directorReferences = const [],
    this.controlnetStrength = 1,
    this.normalizeReferenceStrength = false,
    this.addOriginalImage = false,
    this.imageFormat,
    this.skipCfgAboveSigma,
  });

  final int width;
  final int height;
  final int seed;
  final String negativePrompt;
  final int steps;
  final double scale;
  final String sampler;
  final int sampleCount;
  final String noiseSchedule;
  final double cfgRescale;
  final bool qualityToggle;
  final int ucPreset;
  final V4PromptDto? v4Prompt;
  final V4PromptDto? v4NegativePrompt;
  final List<CharacterPromptDto> characterPrompts;
  final List<String> vibeData;
  final List<double> vibeStrengths;
  final List<double> vibeInformationExtracted;
  final List<DirectorReferenceDto> directorReferences;
  final double controlnetStrength;
  final bool normalizeReferenceStrength;
  final bool addOriginalImage;
  final String? imageFormat;
  final double? skipCfgAboveSigma;

  Map<String, Object?> toJson() => {
    'params_version': 3,
    'width': width,
    'height': height,
    'steps': steps,
    'scale': scale,
    'sampler': sampler,
    'seed': seed,
    'n_samples': sampleCount,
    'noise_schedule': noiseSchedule,
    'cfg_rescale': cfgRescale,
    'negative_prompt': negativePrompt,
    'qualityToggle': qualityToggle,
    'ucPreset': ucPreset,
    if (v4Prompt != null) 'v4_prompt': v4Prompt!.toJson(),
    if (v4NegativePrompt != null)
      'v4_negative_prompt': v4NegativePrompt!.toJson(),
    'legacy': false,
    'legacy_v3_extend': false,
    'legacy_uc': false,
    'sm': false,
    'sm_dyn': false,
    'autoSmea': false,
    'dynamic_thresholding': false,
    'prefer_brownian': true,
    'deliberate_euler_ancestral_bug': false,
    'skip_cfg_above_sigma': skipCfgAboveSigma,
    'add_original_image': addOriginalImage,
    'use_coords': characterPrompts.isNotEmpty,
    'controlnet_strength': controlnetStrength,
    'normalize_reference_strength_multiple': normalizeReferenceStrength,
    'characterPrompts': characterPrompts
        .map((prompt) => prompt.toJson())
        .toList(),
    'reference_image_multiple': vibeData,
    'reference_strength_multiple': vibeStrengths,
    'reference_information_extracted_multiple': vibeInformationExtracted,
    if (directorReferences.isNotEmpty) ...{
      'director_reference_images': directorReferences
          .map((reference) => reference.image)
          .toList(),
      'director_reference_descriptions': directorReferences
          .map(
            (reference) => {
              'caption': {
                'base_caption': reference.description,
                'char_captions': <Object?>[],
              },
              'legacy_uc': false,
            },
          )
          .toList(),
      'director_reference_strength_values': directorReferences
          .map((reference) => reference.strength)
          .toList(),
      'director_reference_secondary_strength_values': directorReferences
          .map((reference) => 1 - reference.fidelity)
          .toList(),
      'director_reference_information_extracted': directorReferences
          .map((reference) => reference.informationExtracted)
          .toList(),
    },
    if (imageFormat != null) 'image_format': imageFormat,
  };
}
