import 'package:equatable/equatable.dart';

class DanbooruTag extends Equatable {
  const DanbooruTag({
    required this.tag,
    this.cnName = '',
    this.category = '',
    this.nsfw = '',
    this.count = 0,
    this.score = 0,
    this.wiki = '',
    this.sources = const [],
    this.origin = '',
  });

  final String tag;
  final String cnName;
  final String category;
  final String nsfw;
  final int count;
  final double score;
  final String wiki;
  final List<String> sources;
  final String origin;

  String get novelAiTag => tag.trim().replaceAll('_', ' ');

  bool get isNsfw {
    final value = nsfw.toLowerCase();
    return const {'questionable', 'explicit', 'q', 'e', 'r'}.contains(value);
  }

  @override
  List<Object?> get props => [tag, origin];
}

class ExtractedKeywords extends Equatable {
  const ExtractedKeywords({
    this.characters = const [],
    this.scene = const [],
    this.style = const [],
    this.nsfw = const [],
  });

  final List<String> characters;
  final List<String> scene;
  final List<String> style;
  final List<String> nsfw;

  bool get isEmpty =>
      characters.isEmpty && scene.isEmpty && style.isEmpty && nsfw.isEmpty;

  Map<String, Object?> toJson() => {
    'characters': characters,
    'scene': scene,
    'style': style,
    'nsfw': nsfw,
  };

  factory ExtractedKeywords.fromJson(Map<String, Object?> json) =>
      ExtractedKeywords(
        characters: _strings(json['characters']),
        scene: _strings(json['scene']),
        style: _strings(json['style']),
        nsfw: _strings(json['nsfw']),
      );

  @override
  List<Object?> get props => [characters, scene, style, nsfw];
}

class DanbooruTagPool extends Equatable {
  const DanbooruTagPool({
    this.globalTags = const [],
    this.perCharacterTags = const [],
  });

  final List<DanbooruTag> globalTags;
  final List<List<DanbooruTag>> perCharacterTags;

  bool get isEmpty =>
      globalTags.isEmpty && perCharacterTags.every((tags) => tags.isEmpty);

  Iterable<DanbooruTag> get all => [
    ...globalTags,
    ...perCharacterTags.expand((tags) => tags),
  ];

  @override
  List<Object?> get props => [globalTags, perCharacterTags];
}

class ComposedCharacterPrompt extends Equatable {
  const ComposedCharacterPrompt({
    required this.prompt,
    this.negativePrompt = '',
  });

  final String prompt;
  final String negativePrompt;

  factory ComposedCharacterPrompt.fromJson(Map<String, Object?> json) =>
      ComposedCharacterPrompt(
        prompt: json['prompt']?.toString() ?? '',
        negativePrompt: json['negative_prompt']?.toString() ?? '',
      );

  @override
  List<Object?> get props => [prompt, negativePrompt];
}

class PromptAssistantResult extends Equatable {
  const PromptAssistantResult({
    required this.positive,
    required this.negative,
    this.characters = const [],
    this.notes = '',
  });

  final String positive;
  final String negative;
  final List<ComposedCharacterPrompt> characters;
  final String notes;

  factory PromptAssistantResult.fromJson(Map<String, Object?> json) {
    final rawCharacters = json['characters'];
    return PromptAssistantResult(
      positive: json['positive']?.toString() ?? '',
      negative: json['negative']?.toString() ?? '',
      characters: rawCharacters is List
          ? rawCharacters
                .whereType<Map>()
                .map(
                  (item) => ComposedCharacterPrompt.fromJson(
                    Map<String, Object?>.from(item),
                  ),
                )
                .toList()
          : const [],
      notes: json['notes']?.toString() ?? '',
    );
  }

  @override
  List<Object?> get props => [positive, negative, characters, notes];
}

List<String> _strings(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList();
}
