import 'package:equatable/equatable.dart';

enum CharacterReferenceType { characterAndStyle, character, style }

class CharacterPosition extends Equatable {
  const CharacterPosition({required this.x, required this.y});

  final double x;
  final double y;

  Map<String, Object?> toJson() => {'x': x, 'y': y};

  factory CharacterPosition.fromJson(Map<String, Object?> json) =>
      CharacterPosition(
        x: ((json['x'] as num?)?.toDouble() ?? 0.5).clamp(0, 1),
        y: ((json['y'] as num?)?.toDouble() ?? 0.5).clamp(0, 1),
      );

  @override
  List<Object?> get props => [x, y];
}

class CharacterPrompt extends Equatable {
  const CharacterPrompt({
    required this.prompt,
    this.negativePrompt = '',
    this.position = const CharacterPosition(x: 0.5, y: 0.5),
    this.enabled = true,
  });

  final String prompt;
  final String negativePrompt;
  final CharacterPosition position;
  final bool enabled;

  CharacterPrompt copyWith({
    String? prompt,
    String? negativePrompt,
    CharacterPosition? position,
    bool? enabled,
  }) => CharacterPrompt(
    prompt: prompt ?? this.prompt,
    negativePrompt: negativePrompt ?? this.negativePrompt,
    position: position ?? this.position,
    enabled: enabled ?? this.enabled,
  );

  Map<String, Object?> toJson() => {
    'prompt': prompt,
    'negativePrompt': negativePrompt,
    'position': position.toJson(),
    'enabled': enabled,
  };

  factory CharacterPrompt.fromJson(Map<String, Object?> json) =>
      CharacterPrompt(
        prompt: json['prompt']?.toString() ?? '',
        negativePrompt: json['negativePrompt']?.toString() ?? '',
        position: json['position'] is Map
            ? CharacterPosition.fromJson(
                Map<String, Object?>.from(json['position']! as Map),
              )
            : const CharacterPosition(x: 0.5, y: 0.5),
        enabled: json['enabled'] != false,
      );

  @override
  List<Object?> get props => [prompt, negativePrompt, position, enabled];
}

class VibeReference extends Equatable {
  const VibeReference({
    this.imagePath,
    this.sourceImageBase64,
    this.encodedData,
    this.displayName,
    this.thumbnailBase64,
    this.strength = 0.7,
    this.informationExtracted = 0.7,
    this.encodingCache = const {},
    this.enabled = true,
  });

  final String? imagePath;

  /// Original reference image embedded by an imported vibe file. Unlike the
  /// thumbnail, this can be sent to encode-vibe again at another IE value.
  final String? sourceImageBase64;

  /// The encoded vibe data at the **current** IE value (null when not yet
  /// encoded for the active IE setting).
  final String? encodedData;
  final String? displayName;

  /// Base64-encoded thumbnail image extracted from vibe files for preview.
  final String? thumbnailBase64;
  final double strength;
  final double informationExtracted;

  /// Multi-slot cache: IE value (rounded to 2 dp) → encodedData.
  /// Lets the user switch IE freely without losing previous encodings.
  final Map<double, String> encodingCache;
  final bool enabled;

  /// Whether generation can use this reference without consulting UI state.
  bool get hasSource =>
      hasReencodeSource ||
      (encodedData?.isNotEmpty ?? false) ||
      encodingCache.isNotEmpty;

  bool get hasReencodeSource =>
      (imagePath?.isNotEmpty ?? false) ||
      (sourceImageBase64?.isNotEmpty ?? false);

  /// The encoded data for the current IE, from the cache or the direct field.
  String? get activeEncoding {
    final key = _ieKey(informationExtracted);
    return encodingCache[key] ?? encodedData;
  }

  bool get hasEncoding => activeEncoding != null && activeEncoding!.isNotEmpty;

  /// True when the active IE has no cached encoding yet (needs to be encoded).
  /// An empty string in [encodedData] is a cold-restore placeholder and must
  /// behave like `null` so the UI prompts the user to re-encode.
  bool get needsReencode {
    final hasData =
        (encodedData != null && encodedData!.isNotEmpty) ||
        encodingCache.isNotEmpty;
    if (!hasData) return false;
    return !hasEncoding;
  }

  static double _ieKey(double ie) => double.parse(ie.toStringAsFixed(2));

  /// Returns a copy with [encoded] stored for the current IE value.
  VibeReference withEncoding(String encoded) {
    final key = _ieKey(informationExtracted);
    final newCache = Map<double, String>.from(encodingCache)..[key] = encoded;
    return copyWith(encodedData: encoded, encodingCache: newCache);
  }

  /// Returns a copy at the new IE, with [encodedData] swapped to the cached
  /// encoding for that IE (or cleared when there is no cache hit).
  ///
  /// Built via the constructor rather than [copyWith] because copyWith's
  /// null-coalescing cannot clear an existing encoding.
  VibeReference withInformationExtracted(double value) => VibeReference(
    imagePath: imagePath,
    sourceImageBase64: sourceImageBase64,
    encodedData: encodingCache[_ieKey(value)],
    displayName: displayName,
    thumbnailBase64: thumbnailBase64,
    strength: strength,
    informationExtracted: value,
    encodingCache: encodingCache,
    enabled: enabled,
  );

  VibeReference copyWith({
    String? imagePath,
    String? sourceImageBase64,
    String? encodedData,
    String? displayName,
    String? thumbnailBase64,
    double? strength,
    double? informationExtracted,
    Map<double, String>? encodingCache,
    bool? enabled,
  }) => VibeReference(
    imagePath: imagePath ?? this.imagePath,
    sourceImageBase64: sourceImageBase64 ?? this.sourceImageBase64,
    encodedData: encodedData ?? this.encodedData,
    displayName: displayName ?? this.displayName,
    thumbnailBase64: thumbnailBase64 ?? this.thumbnailBase64,
    strength: strength ?? this.strength,
    informationExtracted: informationExtracted ?? this.informationExtracted,
    encodingCache: encodingCache ?? this.encodingCache,
    enabled: enabled ?? this.enabled,
  );

  Map<String, Object?> toJson() => {
    'imagePath': imagePath,
    'displayName': displayName,
    'thumbnailBase64': thumbnailBase64,
    'strength': strength,
    'informationExtracted': informationExtracted,
    'enabled': enabled,
    // Whether this reference had a usable encoding at snapshot time. Large
    // base64 payloads (sourceImageBase64 / encodingCache) are intentionally
    // excluded so a multi-MB vibe file never blocks the main isolate during
    // task snapshot serialisation. The in-memory task retains the full data;
    // only a cold-restored task loses it and must re-encode.
    'hadEncoding': hasEncoding,
  };

  factory VibeReference.fromJson(Map<String, Object?> json) {
    final ie = (json['informationExtracted'] as num?)?.toDouble() ?? 0.7;
    final hadEncoding =
        json['hadEncoding'] == true ||
        (json['encodedData']?.toString().isNotEmpty ?? false);
    return VibeReference(
      imagePath: json['imagePath']?.toString(),
      displayName: json['displayName']?.toString(),
      thumbnailBase64: json['thumbnailBase64']?.toString(),
      strength: (json['strength'] as num?)?.toDouble() ?? 0.7,
      informationExtracted: ie,
      enabled: json['enabled'] != false,
      // A cold-restored task no longer carries the encoded payload. Marking
      // the reference as needing re-encode lets the UI prompt the user and
      // keeps generation from silently dropping the vibe.
      encodedData: hadEncoding ? '' : null,
    );
  }

  @override
  List<Object?> get props => [
    imagePath,
    sourceImageBase64,
    encodedData,
    displayName,
    thumbnailBase64,
    strength,
    informationExtracted,
    encodingCache,
    enabled,
  ];
}

class CharacterReference extends Equatable {
  const CharacterReference({
    required this.imagePath,
    this.type = CharacterReferenceType.characterAndStyle,
    this.strength = 1,
    this.fidelity = 0.75,
    this.informationExtracted = 1,
    this.enabled = true,
  });

  final String imagePath;
  final CharacterReferenceType type;
  final double strength;
  final double fidelity;
  final double informationExtracted;
  final bool enabled;

  String get description => switch (type) {
    CharacterReferenceType.characterAndStyle => 'character&style',
    CharacterReferenceType.character => 'character',
    CharacterReferenceType.style => 'style',
  };

  CharacterReference copyWith({
    String? imagePath,
    CharacterReferenceType? type,
    double? strength,
    double? fidelity,
    double? informationExtracted,
    bool? enabled,
  }) => CharacterReference(
    imagePath: imagePath ?? this.imagePath,
    type: type ?? this.type,
    strength: strength ?? this.strength,
    fidelity: fidelity ?? this.fidelity,
    informationExtracted: informationExtracted ?? this.informationExtracted,
    enabled: enabled ?? this.enabled,
  );

  Map<String, Object?> toJson() => {
    'imagePath': imagePath,
    'type': type.name,
    'strength': strength,
    'fidelity': fidelity,
    'informationExtracted': informationExtracted,
    'enabled': enabled,
  };

  factory CharacterReference.fromJson(Map<String, Object?> json) =>
      CharacterReference(
        imagePath: json['imagePath']?.toString() ?? '',
        type: CharacterReferenceType.values.firstWhere(
          (value) => value.name == json['type']?.toString(),
          orElse: () => CharacterReferenceType.characterAndStyle,
        ),
        strength: (json['strength'] as num?)?.toDouble() ?? 1,
        fidelity: (json['fidelity'] as num?)?.toDouble() ?? 0.75,
        informationExtracted:
            (json['informationExtracted'] as num?)?.toDouble() ?? 1,
        enabled: json['enabled'] != false,
      );

  @override
  List<Object?> get props => [
    imagePath,
    type,
    strength,
    fidelity,
    informationExtracted,
    enabled,
  ];
}
