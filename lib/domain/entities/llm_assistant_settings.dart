import 'package:equatable/equatable.dart';

abstract final class PromptTemplateDefaults {
  static const version = 3;

  static const agentPrompt = '''你是绘境的主 Agent，一位熟悉 NovelAI、Danbooru 与视觉创作的多轮对话伙伴。

你可以理解和讨论用户的创作意图，分析用户附加的图片，解释构图、镜头、光影、角色、服装与标签，提出创意建议，并在用户需要时创建或修改可直接用于 NovelAI 的提示词。

可用工具：
- `danbooru_search`：搜索真实的 Danbooru 标签。
- `danbooru_related`：查询已确认标签的相关共现标签。
- `submit_prompt_result`：提交全局正负面提示词，以及可选的多人正负面提示词和人物位置。
当专有角色、作品、服装变体、生僻动作或标签拼写需要确认时使用 Danbooru 工具，不要捏造专有标签。当用户明确要求生成、整理、修改、优化、补全或应用提示词时，使用 `submit_prompt_result`；普通问答、图片分析和创作讨论直接自然回复，不调用该工具，也不要在正文输出结构化 JSON。`submit_prompt_result` 只能修改提示词和人物位置，不能修改模型、画幅、步数、采样器、Scale、Seed 或其他生成参数。

对话规则：
1. 根据用户当前问题直接回应，并结合完整会话上下文持续讨论。
2. 收到图片时客观说明可见内容，不推断无法确认的信息。
3. 可以主动提出有价值的构图、镜头、光影、材质、环境和氛围建议，但不得擅自改变用户明确指定的人物、服装、剧情和限制。
4. 回答使用简体中文；Danbooru 与 NovelAI 标签保留准确英文形式。

使用 `submit_prompt_result` 时遵循以下规则：
1. 输出范围仅包括全局 positive、全局 negative，以及最多 6 个角色各自的 prompt、negative_prompt、x、y、enabled。
2. 使用英文、半角逗号分隔的 tag-based 结构，不写英文自然语言长句。
3. 全局正向提示词按重要性组织：艺术家/风格与质量 → 人数与性别 → 角色身份/作品 → 身体特征 → 服装配饰 → 动作表情 → 环境背景 → 构图视角与光影 → 整体氛围，避免机械堆叠同义词。
4. 精确强调使用 NovelAI 数字权重 `n::tag::`。增强通常用 1.1–1.4，弱化通常用 0.6–0.9；只对少量关键内容加权，不使用旧式花括号或方括号权重。
5. 已知角色、作品、皮肤或变体使用经工具确认的准确 Danbooru 标签。
6. 用户明确要求画面文字时，保留独立的 `TEXT: 内容` 指令，并可补充文字样式、位置或载体标签。
7. 多角色时，全局 positive 只放共享的画质、风格、场景、构图与光影；每个角色的身份、外貌、服装、表情和动作放入对应角色提示词，数量必须与用户描述一致。
8. 人物位置使用 0.1、0.3、0.5、0.7、0.9 的 5×5 坐标；x 从左到右，y 从上到下。根据构图为每个角色填写位置。
9. 互动动作拆到角色提示词：施动方使用 `source#action`，受动方使用 `target#action`，对等互动使用 `mutual#action`。
10. negative 针对用户不希望出现的内容和常见画面缺陷，保持克制。
11. 保留用户当前提示词中有效且不冲突的内容，并进行去重、排序和必要加权。

工具参数中的 notes 用简体中文简要说明关键设计、工具校准结果与权重。''';

  static const visionInstruction =
      '先客观识别图片中可见的角色、外貌、服装、姿势、表情、场景、构图、光影和画风，再将其整理为简体中文画面描述。不要推断不可见或无法确认的信息，只输出描述文本。';
}

class PromptTemplateSet extends Equatable {
  const PromptTemplateSet({
    this.version = PromptTemplateDefaults.version,
    this.agentPrompt = PromptTemplateDefaults.agentPrompt,
  });

  final int version;
  final String agentPrompt;

  PromptTemplateSet copyWith({int? version, String? agentPrompt}) =>
      PromptTemplateSet(
        version: version ?? this.version,
        agentPrompt: agentPrompt ?? this.agentPrompt,
      );

  Map<String, Object?> toJson() => {
    'version': version,
    'agent_prompt': agentPrompt,
  };

  factory PromptTemplateSet.fromJson(Map<String, Object?> json) {
    final current = json['agent_prompt']?.toString().trim() ?? '';
    return PromptTemplateSet(
      version: PromptTemplateDefaults.version,
      agentPrompt: current.isNotEmpty
          ? current
          : PromptTemplateDefaults.agentPrompt,
    );
  }

  @override
  List<Object?> get props => [version, agentPrompt];
}

class LlmAssistantSettings extends Equatable {
  const LlmAssistantSettings({
    this.providerName = 'OpenAI 兼容服务',
    this.baseUrl = 'https://api.openai.com',
    this.model = '',
    this.visionModel = '',
    this.danbooruBaseUrl = '',
    this.danbooruToolsEnabled = true,
    this.showNsfw = false,
    this.autoApplyPrompt = false,
    this.prompts = const PromptTemplateSet(),
  });

  final String providerName;
  final String baseUrl;
  final String model;

  /// Retained only for old backup compatibility. New code always uses [model].
  final String visionModel;
  final String danbooruBaseUrl;
  final bool danbooruToolsEnabled;
  final bool showNsfw;
  final bool autoApplyPrompt;
  final PromptTemplateSet prompts;

  LlmAssistantSettings copyWith({
    String? providerName,
    String? baseUrl,
    String? model,
    String? visionModel,
    String? danbooruBaseUrl,
    bool? danbooruToolsEnabled,
    bool? showNsfw,
    bool? autoApplyPrompt,
    PromptTemplateSet? prompts,
  }) => LlmAssistantSettings(
    providerName: providerName ?? this.providerName,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    visionModel: visionModel ?? this.visionModel,
    danbooruBaseUrl: danbooruBaseUrl ?? this.danbooruBaseUrl,
    danbooruToolsEnabled: danbooruToolsEnabled ?? this.danbooruToolsEnabled,
    showNsfw: showNsfw ?? this.showNsfw,
    autoApplyPrompt: autoApplyPrompt ?? this.autoApplyPrompt,
    prompts: prompts ?? this.prompts,
  );

  Map<String, Object?> toJson() => {
    'provider_name': providerName,
    'base_url': baseUrl,
    'model': model,
    'danbooru_base_url': danbooruBaseUrl,
    'danbooru_tools_enabled': danbooruToolsEnabled,
    'show_nsfw': showNsfw,
    'auto_apply_prompt': autoApplyPrompt,
    'prompts': prompts.toJson(),
  };

  factory LlmAssistantSettings.fromJson(Map<String, Object?> json) {
    final promptJson = json['prompts'];
    final storedModel = json['model']?.toString().trim() ?? '';
    final legacyVisionModel = json['vision_model']?.toString().trim() ?? '';
    final model = storedModel.isNotEmpty ? storedModel : legacyVisionModel;
    return LlmAssistantSettings(
      providerName: json['provider_name']?.toString() ?? 'OpenAI 兼容服务',
      baseUrl: json['base_url']?.toString() ?? 'https://api.openai.com',
      model: model,
      visionModel: model,
      danbooruBaseUrl: json['danbooru_base_url']?.toString() ?? '',
      danbooruToolsEnabled: json['danbooru_tools_enabled'] != false,
      showNsfw: json['show_nsfw'] == true,
      autoApplyPrompt: json['auto_apply_prompt'] == true,
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
    danbooruBaseUrl,
    danbooruToolsEnabled,
    showNsfw,
    autoApplyPrompt,
    prompts,
  ];
}
