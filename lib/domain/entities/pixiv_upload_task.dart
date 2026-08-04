import 'package:equatable/equatable.dart';

/// Lifecycle of a single Pixiv publish job inside the upload queue.
enum PixivUploadStatus {
  pending,
  uploading,
  cooldown,
  completed,
  failed,
  canceled,
}

/// Pixiv age rating tiers, mapped 1:1 to the `xRestrict` form field.
enum PixivXRestrict {
  /// 全年龄 — `general`. `sexual` must be `false`.
  general,

  /// R-18 — `r18`.
  r18,

  /// R-18G (grotesque) — `r18g`.
  r18g,
}

/// Whether the work is AI-generated, mapped to the `aiType` form field.
enum PixivAiType {
  /// 人类创作 — `notAiGenerated`.
  human,

  /// AI 生成作品 — `aiGenerated`.
  aiGenerated,
}

/// Visibility scope of the published work, mapped to `restrict`.
enum PixivRestrict {
  /// 向所有人公开 — `public`.
  public,

  /// 仅我的粉丝 — `myFans`.
  myFans,

  /// 仅我的好友 — `myFriends`.
  myFriends,
}

/// One Pixiv illustration submission. [imagePaths] are absolute local paths.
///
/// Every field here is user-editable on the publish page and maps directly to a
/// Pixiv AJAX upload form key in `PixivApiService.uploadIllustration`.
class PixivUploadTask extends Equatable {
  const PixivUploadTask({
    required this.id,
    required this.imagePaths,
    required this.title,
    required this.caption,
    required this.tags,
    required this.xRestrict,
    required this.aiType,
    required this.restrict,
    required this.allowComment,
    required this.allowTagEdit,
    required this.sexual,
    required this.attributes,
    required this.ratings,
    required this.responseAutoAccept,
    required this.original,
    required this.stripMetadata,
    required this.createdAt,
    this.status = PixivUploadStatus.pending,
    this.illustId,
    this.error,
    this.completedAt,
    this.cooldownUntil,
  });

  final String id;
  final List<String> imagePaths;
  final String title;
  final String caption;
  final List<String> tags;

  /// 年龄限制（一般 / R-18 / R-18G）。
  final PixivXRestrict xRestrict;

  /// AI 生成作品声明。
  final PixivAiType aiType;

  /// 限制公开范围。
  final PixivRestrict restrict;

  /// 作品评论功能。
  final bool allowComment;

  /// 允许他人编辑标签。
  final bool allowTagEdit;

  /// 性相关内容（仅当 [xRestrict] 为 general 时由 Pixiv 强制为 false）。
  final bool sexual;

  /// 内容属性开关：BL / 百合 / 兽人 / 萝莉。
  final PixivAttributes attributes;

  /// 安全评级开关：暴力 / 反社会 / 毒品 / 宗教 / 思想。
  final PixivRatings ratings;

  /// 自动接受作品回复。
  final bool responseAutoAccept;

  /// 原创声明。
  final bool original;

  final bool stripMetadata;
  final PixivUploadStatus status;
  final String? illustId;
  final String? error;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? cooldownUntil;

  /// Convenience for legacy callers / settings defaults: true when R-18 or R-18G.
  bool get isR18 => xRestrict != PixivXRestrict.general;

  PixivUploadTask copyWith({
    List<String>? imagePaths,
    String? title,
    String? caption,
    List<String>? tags,
    PixivXRestrict? xRestrict,
    PixivAiType? aiType,
    PixivRestrict? restrict,
    bool? allowComment,
    bool? allowTagEdit,
    bool? sexual,
    PixivAttributes? attributes,
    PixivRatings? ratings,
    bool? responseAutoAccept,
    bool? original,
    bool? stripMetadata,
    PixivUploadStatus? status,
    String? illustId,
    String? error,
    DateTime? completedAt,
    DateTime? cooldownUntil,
    bool clearError = false,
    bool clearCooldown = false,
  }) {
    return PixivUploadTask(
      id: id,
      imagePaths: imagePaths ?? this.imagePaths,
      title: title ?? this.title,
      caption: caption ?? this.caption,
      tags: tags ?? this.tags,
      xRestrict: xRestrict ?? this.xRestrict,
      aiType: aiType ?? this.aiType,
      restrict: restrict ?? this.restrict,
      allowComment: allowComment ?? this.allowComment,
      allowTagEdit: allowTagEdit ?? this.allowTagEdit,
      sexual: sexual ?? this.sexual,
      attributes: attributes ?? this.attributes,
      ratings: ratings ?? this.ratings,
      responseAutoAccept: responseAutoAccept ?? this.responseAutoAccept,
      original: original ?? this.original,
      stripMetadata: stripMetadata ?? this.stripMetadata,
      status: status ?? this.status,
      illustId: illustId ?? this.illustId,
      error: clearError ? null : (error ?? this.error),
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      cooldownUntil: clearCooldown
          ? null
          : (cooldownUntil ?? this.cooldownUntil),
    );
  }

  @override
  List<Object?> get props => [
    id,
    imagePaths,
    title,
    caption,
    tags,
    xRestrict,
    aiType,
    restrict,
    allowComment,
    allowTagEdit,
    sexual,
    attributes,
    ratings,
    responseAutoAccept,
    original,
    stripMetadata,
    status,
    illustId,
    error,
    createdAt,
    completedAt,
    cooldownUntil,
  ];
}

/// Content attribute toggles for the `attributes[*]` form keys.
class PixivAttributes extends Equatable {
  const PixivAttributes({
    this.bl = false,
    this.yuri = false,
    this.furry = false,
    this.lo = false,
  });

  /// Boys Love.
  final bool bl;

  /// 百合.
  final bool yuri;

  /// 兽人 / Furry.
  final bool furry;

  /// 萝莉.
  final bool lo;

  PixivAttributes copyWith({bool? bl, bool? yuri, bool? furry, bool? lo}) {
    return PixivAttributes(
      bl: bl ?? this.bl,
      yuri: yuri ?? this.yuri,
      furry: furry ?? this.furry,
      lo: lo ?? this.lo,
    );
  }

  @override
  List<Object?> get props => [bl, yuri, furry, lo];
}

/// Safety rating toggles for the `ratings[*]` form keys.
class PixivRatings extends Equatable {
  const PixivRatings({
    this.violent = false,
    this.antisocial = false,
    this.drug = false,
    this.religion = false,
    this.thoughts = false,
  });

  /// 暴力表现.
  final bool violent;

  /// 反社会行为.
  final bool antisocial;

  /// 毒品.
  final bool drug;

  /// 宗教.
  final bool religion;

  /// 思想.
  final bool thoughts;

  PixivRatings copyWith({
    bool? violent,
    bool? antisocial,
    bool? drug,
    bool? religion,
    bool? thoughts,
  }) {
    return PixivRatings(
      violent: violent ?? this.violent,
      antisocial: antisocial ?? this.antisocial,
      drug: drug ?? this.drug,
      religion: religion ?? this.religion,
      thoughts: thoughts ?? this.thoughts,
    );
  }

  @override
  List<Object?> get props => [violent, antisocial, drug, religion, thoughts];
}
