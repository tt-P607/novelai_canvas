import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../../core/network/backend_mode.dart';
import 'advanced_generation.dart';

enum GenerationMode { textToImage, imageToImage, inpaint }

enum GenerationTaskStatus {
  draft,
  queued,
  running,
  completed,
  failed,
  cancelled,
  interrupted,
}

class GenerationSpec extends Equatable {
  const GenerationSpec({
    required this.mode,
    required this.backendMode,
    required this.model,
    required this.prompt,
    required this.negativePrompt,
    required this.width,
    required this.height,
    required this.steps,
    required this.scale,
    required this.cfgRescale,
    required this.sampler,
    required this.noiseSchedule,
    required this.seed,
    this.sampleCount = 1,
    this.ucPreset = 1,
    this.quality = true,
    this.sourceImagePath,
    this.maskImagePath,
    this.strength = 0.7,
    this.noise = 0,
    this.addOriginalImage = false,
    this.stream = false,
    this.characterPrompts = const [],
    this.vibeReferences = const [],
    this.characterReferences = const [],
    this.controlnetStrength = 1,
    this.normalizeReferenceStrength = false,
  });

  final GenerationMode mode;
  final BackendMode backendMode;
  final String model;
  final String prompt;
  final String negativePrompt;
  final int width;
  final int height;
  final int steps;
  final double scale;
  final double cfgRescale;
  final String sampler;
  final String noiseSchedule;
  final int seed;
  final int sampleCount;
  final int ucPreset;
  final bool quality;
  final String? sourceImagePath;
  final String? maskImagePath;
  final double strength;
  final double noise;
  final bool addOriginalImage;
  final bool stream;
  final List<CharacterPrompt> characterPrompts;
  final List<VibeReference> vibeReferences;
  final List<CharacterReference> characterReferences;
  final double controlnetStrength;
  final bool normalizeReferenceStrength;

  String get size => '${width}x$height';

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'backendMode': backendMode.name,
    'model': model,
    'prompt': prompt,
    'negativePrompt': negativePrompt,
    'width': width,
    'height': height,
    'steps': steps,
    'scale': scale,
    'cfgRescale': cfgRescale,
    'sampler': sampler,
    'noiseSchedule': noiseSchedule,
    'seed': seed,
    'sampleCount': sampleCount,
    'ucPreset': ucPreset,
    'quality': quality,
    'sourceImagePath': sourceImagePath,
    'maskImagePath': maskImagePath,
    'strength': strength,
    'noise': noise,
    'addOriginalImage': addOriginalImage,
    'stream': stream,
    'characterPrompts': characterPrompts
        .map((value) => value.toJson())
        .toList(),
    'vibeReferences': vibeReferences.map((value) => value.toJson()).toList(),
    'characterReferences': characterReferences
        .map((value) => value.toJson())
        .toList(),
    'controlnetStrength': controlnetStrength,
    'normalizeReferenceStrength': normalizeReferenceStrength,
  };

  factory GenerationSpec.fromJson(Map<String, Object?> json) => GenerationSpec(
    mode: _enumByName(
      GenerationMode.values,
      json['mode']?.toString(),
      GenerationMode.textToImage,
    ),
    backendMode: _enumByName(
      BackendMode.values,
      json['backendMode']?.toString(),
      BackendMode.native,
    ),
    model: json['model']?.toString() ?? 'nai-diffusion-4-5-full',
    prompt: json['prompt']?.toString() ?? '',
    negativePrompt: json['negativePrompt']?.toString() ?? '',
    width: (json['width'] as num?)?.toInt() ?? 832,
    height: (json['height'] as num?)?.toInt() ?? 1216,
    steps: (json['steps'] as num?)?.toInt() ?? 28,
    scale: (json['scale'] as num?)?.toDouble() ?? 5,
    cfgRescale: (json['cfgRescale'] as num?)?.toDouble() ?? 0,
    sampler: json['sampler']?.toString() ?? 'k_euler_ancestral',
    noiseSchedule: json['noiseSchedule']?.toString() ?? 'karras',
    seed: (json['seed'] as num?)?.toInt() ?? 0,
    sampleCount: (json['sampleCount'] as num?)?.toInt() ?? 1,
    ucPreset: (json['ucPreset'] as num?)?.toInt() ?? 1,
    quality: json['quality'] != false,
    sourceImagePath: json['sourceImagePath']?.toString(),
    maskImagePath: json['maskImagePath']?.toString(),
    strength: (json['strength'] as num?)?.toDouble() ?? 0.7,
    noise: (json['noise'] as num?)?.toDouble() ?? 0,
    addOriginalImage: json['addOriginalImage'] == true,
    stream: json['stream'] == true,
    characterPrompts: _jsonObjectList(
      json['characterPrompts'],
    ).map(CharacterPrompt.fromJson).toList(),
    vibeReferences: _jsonObjectList(
      json['vibeReferences'],
    ).map(VibeReference.fromJson).toList(),
    characterReferences: _jsonObjectList(
      json['characterReferences'],
    ).map(CharacterReference.fromJson).toList(),
    controlnetStrength: (json['controlnetStrength'] as num?)?.toDouble() ?? 1,
    normalizeReferenceStrength: json['normalizeReferenceStrength'] == true,
  );

  String encode() => jsonEncode(toJson());

  factory GenerationSpec.decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('生成参数快照必须是 JSON 对象。');
    }
    return GenerationSpec.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  @override
  List<Object?> get props => toJson().values.toList();
}

class GenerationTask extends Equatable {
  const GenerationTask({
    required this.id,
    required this.spec,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.imagePath,
    this.thumbnailPath,
    this.errorMessage,
    this.anlasCost,
    this.retryCount = 0,
    this.favorite = false,
  });

  final String id;
  final GenerationSpec spec;
  final GenerationTaskStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? imagePath;
  final String? thumbnailPath;
  final String? errorMessage;
  final int? anlasCost;
  final int retryCount;
  final bool favorite;

  bool get isTerminal => {
    GenerationTaskStatus.completed,
    GenerationTaskStatus.failed,
    GenerationTaskStatus.cancelled,
  }.contains(status);

  GenerationTask copyWith({
    GenerationTaskStatus? status,
    DateTime? updatedAt,
    String? imagePath,
    String? thumbnailPath,
    String? errorMessage,
    bool clearError = false,
    int? anlasCost,
    int? retryCount,
    bool? favorite,
  }) => GenerationTask(
    id: id,
    spec: spec,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    imagePath: imagePath ?? this.imagePath,
    thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    anlasCost: anlasCost ?? this.anlasCost,
    retryCount: retryCount ?? this.retryCount,
    favorite: favorite ?? this.favorite,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'spec': spec.toJson(),
    'status': status.name,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'image_path': imagePath,
    'thumbnail_path': thumbnailPath,
    'error_message': errorMessage,
    'anlas_cost': anlasCost,
    'retry_count': retryCount,
    'favorite': favorite,
  };

  factory GenerationTask.fromJson(Map<String, Object?> json) {
    final specJson = json['spec'];
    if (specJson is! Map) {
      throw const FormatException('生成任务缺少有效的 spec 对象。');
    }
    return GenerationTask(
      id: json['id']?.toString() ?? '',
      spec: GenerationSpec.fromJson(Map<String, Object?>.from(specJson)),
      status: _enumByName(
        GenerationTaskStatus.values,
        json['status']?.toString(),
        GenerationTaskStatus.interrupted,
      ),
      createdAt: _dateTimeFromJson(json['created_at']),
      updatedAt: _dateTimeFromJson(json['updated_at']),
      imagePath: json['image_path']?.toString(),
      thumbnailPath: json['thumbnail_path']?.toString(),
      errorMessage: json['error_message']?.toString(),
      anlasCost: (json['anlas_cost'] as num?)?.toInt(),
      retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
      favorite: json['favorite'] == true,
    );
  }

  @override
  List<Object?> get props => [
    id,
    spec,
    status,
    createdAt,
    updatedAt,
    imagePath,
    thumbnailPath,
    errorMessage,
    anlasCost,
    retryCount,
    favorite,
  ];
}

List<Map<String, Object?>> _jsonObjectList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, Object?>.from(item))
      .toList();
}

DateTime _dateTimeFromJson(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return (parsed ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
      .toUtc();
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
