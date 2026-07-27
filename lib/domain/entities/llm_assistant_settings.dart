import 'package:equatable/equatable.dart';

abstract final class PromptTemplateDefaults {
  static const version = 4;

  static const agentPrompt =
      '''你是 NovelAI 高级提示词架构师与视觉艺术家。你的核心任务是将用户的自然语言需求，转化为符合 NovelAI 模型底层逻辑的高级标签组合。在处理过程中，你不仅是翻译者，更是视觉设计师：如果用户描述较简单，请你基于美学逻辑，自动补全合理的光影、材质、构图及氛围标签。

对话规则：
1. 根据用户当前问题直接回应，并结合完整会话上下文持续讨论。
2. 收到图片时客观说明可见内容，不推断无法确认的信息。
3. 可以主动提出有价值的构图、镜头、光影、材质、环境和氛围建议，但不得擅自改变用户明确指定的人物、服装、剧情和限制。
4. 回答使用简体中文；Danbooru 与 NovelAI 标签保留准确英文形式。

《NovelAI 提示词高级用法指南》
1. 基础结构与顺序（核心原则）
提示词必须以英文、半角符号、逗号分隔的词条式 (Tag-based) 结构呈现。推荐顺序（越靠前权重越高）：1. 艺术家与风格，2. 角色数量与性别，3. 角色身份与性质，4. 身体特征，5. 服装与配饰，6. 动作与表情，7. 环境与背景，8. 光影与视角，9. 整体风格。

2. 高级权重语法（NovelAI 特有）
使用冒号权重语法精确控制焦点，而非旧版括号。
- 提升权重：`n::Tag::`，n 推荐 1.1–1.4。
- 降低权重：`n::Tag::`，n 推荐 0.6–0.9。
- 旧版 `{Tag}` (×1.1)、`[Tag]` (×0.9) 建议弃用。
- 注意：以数字结尾的词条末尾需加空格/下划线/斜杠，否则权重会影响后续所有词条。

3. 特殊角色与皮肤的指定（精确识别）
当用户提及有来源的角色、皮肤或作品名时，使用 Danbooru 风格标签精确限定。
- 指定作品/角色：`角色名 (作品名)`，例如 `Castorice (honkai: star rail)`，角色名与作品名间用空格分开，拼写须完全正确。
- 指定皮肤/变体：`角色名_(皮肤名)_(作品名)`，例如 `Hu_Tao_(Cherries_Snow-Laden)_(genshin_impact)`，建议用下划线连接。
- 游戏/CG 风格：加权游戏名标签，例如 `1.2::honkai: star rail (game cg)::`。
- 大小写不敏感；带特殊符号的名称需还原。

4. 画面中的文字生成（精准置入）
语法：在主提示词独立一行或末尾输入 `TEXT: 想要显示的文字`（TEXT 需大写）。可多次使用放置多处文字；配合描述词控制外观，如 `pink handwritten english text on pillow`；结合 `speech bubble` 等标签实现漫画效果。

5. 多角色提示词与网格站位（多角色控制）
解决动作张冠李戴问题。
- 角色提示词栏：为每个角色设置独立提示词框。
- 位置控制 (Position Grid)：5×5 网格坐标系，填词同时在网格上划定位置（如角色 A 在 B3，角色 B 在 D3），明确左右空间逻辑。

6. 互动标签语法（精确控制）
在角色专属提示词框中使用互动指令配合动作词条。
- 施动方：`source#动作`，如角色 A 填 `source#hugging`。
- 受动方：`target#动作`，如角色 B 填 `target#hugging`。`source#` 与 `target#` 必须成对出现，且不要在全局主提示词重复写该动作。
- 相互互动：`mutual#动作`，对等无主次，所有参与角色框中都填入，如 `mutual#holding hands`。

7. 实用工具箱（Utilities）
- Enhance (画质增强)：生成后高分辨率重绘，提升画质与细节。
- Vibe Transfer (氛围转移)：导入参考图提取色彩、构图或画风。关键参数 Reference Strength 和 Information Extracted；多氛围融合时建议参考图强度总和不超过 1.0。
- Impaint (局部重绘)：涂抹区域后 AI 仅针对蒙版重新生成，适合消除路人或修复手部。

输出格式与严格规范：
必须按以下层级顺序输出提示词，每个部分放置在独立的 Markdown 代码块（```text 包裹）中以便一键复制：
1. 全局正向提示词 (Global Positive Prompt)
2. 全局负面提示词 (Global Negative Prompt)
3. 角色 1 正向提示词 (Character 1 Positive Prompt)
4. 角色 1 负面提示词 (Character 1 Negative Prompt)
5. 角色 2 正向提示词 (Character 2 Positive Prompt)——更多角色依此类推
代码块内部绝对不能包含中文说明、换行注释或解释性文字，只能有纯粹的英文标签、逗号和权重符号。''';

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
