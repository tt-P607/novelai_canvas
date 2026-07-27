import 'package:equatable/equatable.dart';

class ModelInfo extends Equatable {
  const ModelInfo({
    required this.id,
    this.name,
    this.object,
    this.created,
    this.ownedBy,
    this.description = '',
  });

  final String id;

  /// Human-readable display name; falls back to [id] when absent.
  final String? name;
  final String? object;
  final int? created;
  final String? ownedBy;
  final String description;

  String get displayName => name ?? id;

  @override
  List<Object?> get props => [id, name, object, created, ownedBy, description];
}

/// Built-in model catalogue matching NovelAI's official offerings.
/// Used as fallback for native mode (which has no /v1/models endpoint)
/// and as the label source for gateway models.
abstract final class BuiltInModels {
  static const all = <ModelInfo>[
    ModelInfo(
      id: 'nai-diffusion-4-5-full',
      name: 'NAI Diffusion V4.5 Full',
      description:
          '最新最强的全量模型，广泛适用于各种主题和风格，生成质量最高。'
          '支持 V4.5 角色参考、Vibe Transfer 及导演工具。',
    ),
    ModelInfo(
      id: 'nai-diffusion-4-5-curated',
      name: 'NAI Diffusion V4.5 Curated',
      description:
          '基于精选图像子集训练，减少意外生成内容的最新模型。'
          '推荐用于流式生成场景。',
    ),
    ModelInfo(
      id: 'nai-diffusion-4-full',
      name: 'NAI Diffusion V4 Full',
      description: 'V4 全量模型，已被 V4.5 取代。不支持 V4.5 角色参考。',
    ),
    ModelInfo(
      id: 'nai-diffusion-4-curated',
      name: 'NAI Diffusion V4 Curated',
      description: '基于精选图像子集训练的 V4 模型，已被 V4.5 取代。',
    ),
    ModelInfo(
      id: 'nai-diffusion-3',
      name: 'NAI Diffusion V3',
      description: '上一代 SDXL 架构模型，仅保留向后兼容。',
    ),
    ModelInfo(
      id: 'nai-diffusion-3-furry',
      name: 'NAI Diffusion Furry V3',
      description: '上一代 Furry 特化模型，仅保留向后兼容。',
    ),
  ];

  static String nameFor(String id) {
    final match = all.where((model) => model.id == id).firstOrNull;
    return match?.displayName ?? id;
  }

  static String descriptionFor(String id) {
    final match = all.where((model) => model.id == id).firstOrNull;
    return match?.description ?? id;
  }
}
