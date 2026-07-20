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
    this.x = 0.5,
    this.y = 0.5,
    this.enabled = true,
  });

  final String prompt;
  final String negativePrompt;
  final double x;
  final double y;
  final bool enabled;

  Map<String, Object?> toJson() => {
    'prompt': prompt,
    'negative_prompt': negativePrompt,
    'x': x,
    'y': y,
    'enabled': enabled,
  };

  factory ComposedCharacterPrompt.fromJson(Map<String, Object?> json) =>
      ComposedCharacterPrompt(
        prompt: json['prompt']?.toString() ?? '',
        negativePrompt: json['negative_prompt']?.toString() ?? '',
        x: ((json['x'] as num?)?.toDouble() ?? 0.5).clamp(0, 1),
        y: ((json['y'] as num?)?.toDouble() ?? 0.5).clamp(0, 1),
        enabled: json['enabled'] != false,
      );

  @override
  List<Object?> get props => [prompt, negativePrompt, x, y, enabled];
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

  Map<String, Object?> toJson() => {
    'positive': positive,
    'negative': negative,
    'characters': characters.map((value) => value.toJson()).toList(),
    'notes': notes,
  };

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

enum PromptChatRole { user, assistant, notice }

class PromptChatMessage extends Equatable {
  const PromptChatMessage({
    required this.role,
    required this.content,
    this.imagePath,
    this.createdAt,
    this.promptResult,
  });

  final PromptChatRole role;
  final String content;
  final String? imagePath;
  final DateTime? createdAt;
  final PromptAssistantResult? promptResult;

  Map<String, Object?> toJson() => {
    'role': role.name,
    'content': content,
    'image_path': imagePath,
    'created_at': createdAt?.toIso8601String(),
    'prompt_result': promptResult?.toJson(),
  };

  factory PromptChatMessage.fromJson(Map<String, Object?> json) {
    final rawPromptResult = json['prompt_result'];
    return PromptChatMessage(
      role: PromptChatRole.values.firstWhere(
        (value) => value.name == json['role']?.toString(),
        orElse: () => PromptChatRole.user,
      ),
      content: json['content']?.toString() ?? '',
      imagePath: json['image_path']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      promptResult: rawPromptResult is Map
          ? PromptAssistantResult.fromJson(
              Map<String, Object?>.from(rawPromptResult),
            )
          : null,
    );
  }

  @override
  List<Object?> get props => [
    role,
    content,
    imagePath,
    createdAt,
    promptResult,
  ];
}

class PromptAssistantReply extends Equatable {
  const PromptAssistantReply({required this.message, this.promptResult});

  final String message;
  final PromptAssistantResult? promptResult;

  @override
  List<Object?> get props => [message, promptResult];
}

class PromptChatSession extends Equatable {
  const PromptChatSession({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.archived = false,
    this.messages = const [],
  });

  final String id;
  final String title;
  final DateTime updatedAt;
  final bool archived;
  final List<PromptChatMessage> messages;

  PromptChatSession copyWith({
    String? title,
    DateTime? updatedAt,
    bool? archived,
    List<PromptChatMessage>? messages,
  }) => PromptChatSession(
    id: id,
    title: title ?? this.title,
    updatedAt: updatedAt ?? this.updatedAt,
    archived: archived ?? this.archived,
    messages: messages ?? this.messages,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'updated_at': updatedAt.toIso8601String(),
    'archived': archived,
    'messages': messages.map((message) => message.toJson()).toList(),
  };

  factory PromptChatSession.fromJson(Map<String, Object?> json) =>
      PromptChatSession(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '未命名会话',
        updatedAt:
            DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
            DateTime.now(),
        archived: json['archived'] == true,
        messages: json['messages'] is List
            ? (json['messages'] as List)
                  .whereType<Map>()
                  .map(
                    (value) => PromptChatMessage.fromJson(
                      Map<String, Object?>.from(value),
                    ),
                  )
                  .toList()
            : const [],
      );

  @override
  List<Object?> get props => [id, title, updatedAt, archived, messages];
}

List<String> _strings(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList();
}
