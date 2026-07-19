import 'package:equatable/equatable.dart';

enum PromptTemplateKind {
  keywordExtraction,
  promptComposition,
  visionAnalysis,
  jsonRepair,
}

abstract final class PromptTemplateDefaults {
  static const version = 1;

  static const keywordExtraction =
      '''你是 Danbooru 标签检索的关键词抽取器。把用户的中文或英文画面描述拆成适合语义检索的短语。
只输出 JSON，不要 Markdown 或解释：
{"characters":["每个角色一项"],"scene":["场景、动作、表情"],"style":["画风、构图、光影"],"nsfw":["仅用户明确要求时填写"]}
不要添加用户没有描述的内容；每项尽量保持 1-4 个词。''';

  static const promptComposition =
      '''你是 NovelAI Danbooru 提示词整理器。你只能使用用户原始描述与候选池中真实存在的 tag，不得创造候选池之外的英文 tag。
请输出严格 JSON：
{"positive":"逗号分隔的全局正向 tag","negative":"逗号分隔的负向 tag","characters":[{"prompt":"角色正向 tag","negative_prompt":"角色负向 tag"}],"notes":"简短说明"}
多角色时，全局 positive 只放画质、场景、风格；角色独有外貌、服装、动作放入对应 characters。NovelAI 使用空格风格 tag，把下划线转换为空格。''';

  static const visionAnalysis =
      '''你是 NovelAI 图片识别助手。分析图片中可见的角色、外貌、服装、姿势、表情、场景、构图、光影和画风。
只输出 JSON，不要 Markdown 或解释：
{"description":"简体中文画面描述","characters":["每个角色一项"],"scene":["场景与动作"],"style":["画风、构图与光影"]}
不要推断图片中不可见或无法确认的信息。''';

  static const jsonRepair =
      '''你是 JSON 修复器。把用户提供的模型输出修复成合法 JSON，只输出修复后的 JSON，不要 Markdown、解释或额外文字。保持原始语义，不新增内容。''';

  static String valueOf(PromptTemplateKind kind) => switch (kind) {
    PromptTemplateKind.keywordExtraction => keywordExtraction,
    PromptTemplateKind.promptComposition => promptComposition,
    PromptTemplateKind.visionAnalysis => visionAnalysis,
    PromptTemplateKind.jsonRepair => jsonRepair,
  };
}

class PromptTemplateSet extends Equatable {
  const PromptTemplateSet({
    this.version = PromptTemplateDefaults.version,
    this.keywordExtraction = PromptTemplateDefaults.keywordExtraction,
    this.promptComposition = PromptTemplateDefaults.promptComposition,
    this.visionAnalysis = PromptTemplateDefaults.visionAnalysis,
    this.jsonRepair = PromptTemplateDefaults.jsonRepair,
  });

  final int version;
  final String keywordExtraction;
  final String promptComposition;
  final String visionAnalysis;
  final String jsonRepair;

  String valueOf(PromptTemplateKind kind) => switch (kind) {
    PromptTemplateKind.keywordExtraction => keywordExtraction,
    PromptTemplateKind.promptComposition => promptComposition,
    PromptTemplateKind.visionAnalysis => visionAnalysis,
    PromptTemplateKind.jsonRepair => jsonRepair,
  };

  PromptTemplateSet update(
    PromptTemplateKind kind,
    String value,
  ) => switch (kind) {
    PromptTemplateKind.keywordExtraction => copyWith(keywordExtraction: value),
    PromptTemplateKind.promptComposition => copyWith(promptComposition: value),
    PromptTemplateKind.visionAnalysis => copyWith(visionAnalysis: value),
    PromptTemplateKind.jsonRepair => copyWith(jsonRepair: value),
  };

  PromptTemplateSet reset(PromptTemplateKind kind) =>
      update(kind, PromptTemplateDefaults.valueOf(kind));

  PromptTemplateSet copyWith({
    int? version,
    String? keywordExtraction,
    String? promptComposition,
    String? visionAnalysis,
    String? jsonRepair,
  }) => PromptTemplateSet(
    version: version ?? this.version,
    keywordExtraction: keywordExtraction ?? this.keywordExtraction,
    promptComposition: promptComposition ?? this.promptComposition,
    visionAnalysis: visionAnalysis ?? this.visionAnalysis,
    jsonRepair: jsonRepair ?? this.jsonRepair,
  );

  Map<String, Object?> toJson() => {
    'version': version,
    'keyword_extraction': keywordExtraction,
    'prompt_composition': promptComposition,
    'vision_analysis': visionAnalysis,
    'json_repair': jsonRepair,
  };

  factory PromptTemplateSet.fromJson(
    Map<String, Object?> json,
  ) => PromptTemplateSet(
    version:
        (json['version'] as num?)?.toInt() ?? PromptTemplateDefaults.version,
    keywordExtraction:
        json['keyword_extraction']?.toString() ??
        PromptTemplateDefaults.keywordExtraction,
    promptComposition:
        json['prompt_composition']?.toString() ??
        PromptTemplateDefaults.promptComposition,
    visionAnalysis:
        json['vision_analysis']?.toString() ??
        PromptTemplateDefaults.visionAnalysis,
    jsonRepair:
        json['json_repair']?.toString() ?? PromptTemplateDefaults.jsonRepair,
  );

  @override
  List<Object?> get props => [
    version,
    keywordExtraction,
    promptComposition,
    visionAnalysis,
    jsonRepair,
  ];
}

class LlmAssistantSettings extends Equatable {
  const LlmAssistantSettings({
    this.providerName = 'OpenAI 兼容服务',
    this.baseUrl = 'https://api.openai.com',
    this.model = '',
    this.visionModel = '',
    this.danbooruBaseUrl = '',
    this.showNsfw = false,
    this.prompts = const PromptTemplateSet(),
  });

  final String providerName;
  final String baseUrl;
  final String model;
  final String visionModel;
  final String danbooruBaseUrl;
  final bool showNsfw;
  final PromptTemplateSet prompts;

  LlmAssistantSettings copyWith({
    String? providerName,
    String? baseUrl,
    String? model,
    String? visionModel,
    String? danbooruBaseUrl,
    bool? showNsfw,
    PromptTemplateSet? prompts,
  }) => LlmAssistantSettings(
    providerName: providerName ?? this.providerName,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    visionModel: visionModel ?? this.visionModel,
    danbooruBaseUrl: danbooruBaseUrl ?? this.danbooruBaseUrl,
    showNsfw: showNsfw ?? this.showNsfw,
    prompts: prompts ?? this.prompts,
  );

  Map<String, Object?> toJson() => {
    'provider_name': providerName,
    'base_url': baseUrl,
    'model': model,
    'vision_model': visionModel,
    'danbooru_base_url': danbooruBaseUrl,
    'show_nsfw': showNsfw,
    'prompts': prompts.toJson(),
  };

  factory LlmAssistantSettings.fromJson(Map<String, Object?> json) {
    final promptJson = json['prompts'];
    return LlmAssistantSettings(
      providerName: json['provider_name']?.toString() ?? 'OpenAI 兼容服务',
      baseUrl: json['base_url']?.toString() ?? 'https://api.openai.com',
      model: json['model']?.toString() ?? '',
      visionModel: json['vision_model']?.toString() ?? '',
      danbooruBaseUrl: json['danbooru_base_url']?.toString() ?? '',
      showNsfw: json['show_nsfw'] == true,
      prompts: promptJson is Map
          ? PromptTemplateSet.fromJson(Map<String, Object?>.from(promptJson))
          : const PromptTemplateSet(),
    );
  }

  @override
  List<Object?> get props => [
    providerName,
    baseUrl,
    model,
    visionModel,
    danbooruBaseUrl,
    showNsfw,
    prompts,
  ];
}
