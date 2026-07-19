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
    this.encodedData,
    this.strength = 0.7,
    this.informationExtracted = 0.7,
    this.enabled = true,
  });

  final String? imagePath;
  final String? encodedData;
  final double strength;
  final double informationExtracted;
  final bool enabled;

  bool get hasSource =>
      (imagePath?.isNotEmpty ?? false) || (encodedData?.isNotEmpty ?? false);

  VibeReference copyWith({
    String? imagePath,
    String? encodedData,
    double? strength,
    double? informationExtracted,
    bool? enabled,
  }) => VibeReference(
    imagePath: imagePath ?? this.imagePath,
    encodedData: encodedData ?? this.encodedData,
    strength: strength ?? this.strength,
    informationExtracted: informationExtracted ?? this.informationExtracted,
    enabled: enabled ?? this.enabled,
  );

  Map<String, Object?> toJson() => {
    'imagePath': imagePath,
    'encodedData': encodedData,
    'strength': strength,
    'informationExtracted': informationExtracted,
    'enabled': enabled,
  };

  factory VibeReference.fromJson(Map<String, Object?> json) => VibeReference(
    imagePath: json['imagePath']?.toString(),
    encodedData: json['encodedData']?.toString(),
    strength: (json['strength'] as num?)?.toDouble() ?? 0.7,
    informationExtracted:
        (json['informationExtracted'] as num?)?.toDouble() ?? 0.7,
    enabled: json['enabled'] != false,
  );

  @override
  List<Object?> get props => [
    imagePath,
    encodedData,
    strength,
    informationExtracted,
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
