import 'package:equatable/equatable.dart';

import 'pixiv_upload_task.dart';

/// All user-configurable options for Pixiv publishing.
///
/// Sensitive fields [cookie] and [csrfToken] must be persisted through
/// [SecureCredentialStore] only — never SharedPreferences, SQLite, backups or
/// logs (see rules.md §2.4).
///
/// Fields below `allowTagEdit` mirror the per-artwork options on
/// [PixivUploadTask]; they act as the initial values pre-filled on the publish
/// page, where the user can still override each one per submission.
class PixivSettings extends Equatable {
  const PixivSettings({
    required this.cookie,
    required this.csrfToken,
    required this.proxy,
    required this.captionPrefix,
    required this.defaultTags,
    required this.xRestrictDefault,
    required this.aiTypeDefault,
    required this.restrictDefault,
    required this.allowCommentDefault,
    required this.allowTagEdit,
    required this.sexualDefault,
    required this.attributesDefault,
    required this.ratingsDefault,
    required this.responseAutoAcceptDefault,
    required this.originalDefault,
    required this.stripMetadata,
    required this.suggestTagsEnabled,
    required this.cooldownMinutes,
    required this.junkText,
  });

  final String cookie;
  final String csrfToken;

  /// HTTP/SOCKS proxy like "http://127.0.0.1:7890". Empty means direct.
  final String proxy;
  final String captionPrefix;
  final List<String> defaultTags;

  /// 默认年龄限制。
  final PixivXRestrict xRestrictDefault;

  /// 默认 AI 生成声明。
  final PixivAiType aiTypeDefault;

  /// 默认可见范围。
  final PixivRestrict restrictDefault;

  /// 默认作品评论开关。
  final bool allowCommentDefault;

  final bool allowTagEdit;

  /// 點性相关开关（仅 general 时有效）。
  final bool sexualDefault;

  /// 默认内容属性。
  final PixivAttributes attributesDefault;

  /// 默认安全评级。
  final PixivRatings ratingsDefault;

  /// 默认自动接受回复。
  final bool responseAutoAcceptDefault;

  /// 默认原创声明。
  final bool originalDefault;

  final bool stripMetadata;
  final bool suggestTagsEnabled;
  final int cooldownMinutes;
  final String junkText;

  bool get hasCredentials =>
      cookie.trim().isNotEmpty && csrfToken.trim().isNotEmpty;

  /// Backwards-compatible R-18 default derived from [xRestrictDefault].
  bool get r18Default => xRestrictDefault != PixivXRestrict.general;

  PixivSettings copyWith({
    String? cookie,
    String? csrfToken,
    String? proxy,
    String? captionPrefix,
    List<String>? defaultTags,
    PixivXRestrict? xRestrictDefault,
    PixivAiType? aiTypeDefault,
    PixivRestrict? restrictDefault,
    bool? allowCommentDefault,
    bool? allowTagEdit,
    bool? sexualDefault,
    PixivAttributes? attributesDefault,
    PixivRatings? ratingsDefault,
    bool? responseAutoAcceptDefault,
    bool? originalDefault,
    bool? stripMetadata,
    bool? suggestTagsEnabled,
    int? cooldownMinutes,
    String? junkText,
    // Legacy alias kept so old call sites compiling against r18Default keep
    // working; maps onto xRestrictDefault.
    bool? r18Default,
  }) {
    final resolvedXRestrict = r18Default != null
        ? (r18Default ? PixivXRestrict.r18 : PixivXRestrict.general)
        : xRestrictDefault;
    return PixivSettings(
      cookie: cookie ?? this.cookie,
      csrfToken: csrfToken ?? this.csrfToken,
      proxy: proxy ?? this.proxy,
      captionPrefix: captionPrefix ?? this.captionPrefix,
      defaultTags: defaultTags ?? this.defaultTags,
      xRestrictDefault: resolvedXRestrict ?? this.xRestrictDefault,
      aiTypeDefault: aiTypeDefault ?? this.aiTypeDefault,
      restrictDefault: restrictDefault ?? this.restrictDefault,
      allowCommentDefault: allowCommentDefault ?? this.allowCommentDefault,
      allowTagEdit: allowTagEdit ?? this.allowTagEdit,
      sexualDefault: sexualDefault ?? this.sexualDefault,
      attributesDefault: attributesDefault ?? this.attributesDefault,
      ratingsDefault: ratingsDefault ?? this.ratingsDefault,
      responseAutoAcceptDefault:
          responseAutoAcceptDefault ?? this.responseAutoAcceptDefault,
      originalDefault: originalDefault ?? this.originalDefault,
      stripMetadata: stripMetadata ?? this.stripMetadata,
      suggestTagsEnabled: suggestTagsEnabled ?? this.suggestTagsEnabled,
      cooldownMinutes: cooldownMinutes ?? this.cooldownMinutes,
      junkText: junkText ?? this.junkText,
    );
  }

  static PixivSettings get empty => const PixivSettings(
    cookie: '',
    csrfToken: '',
    proxy: '',
    captionPrefix: '',
    defaultTags: ['NovelAI', 'AIイラスト'],
    xRestrictDefault: PixivXRestrict.general,
    aiTypeDefault: PixivAiType.aiGenerated,
    restrictDefault: PixivRestrict.public,
    allowCommentDefault: true,
    allowTagEdit: true,
    sexualDefault: false,
    attributesDefault: PixivAttributes(),
    ratingsDefault: PixivRatings(),
    responseAutoAcceptDefault: false,
    originalDefault: true,
    stripMetadata: true,
    suggestTagsEnabled: true,
    cooldownMinutes: 10,
    junkText: '',
  );

  @override
  List<Object?> get props => [
    cookie,
    csrfToken,
    proxy,
    captionPrefix,
    defaultTags,
    xRestrictDefault,
    aiTypeDefault,
    restrictDefault,
    allowCommentDefault,
    allowTagEdit,
    sexualDefault,
    attributesDefault,
    ratingsDefault,
    responseAutoAcceptDefault,
    originalDefault,
    stripMetadata,
    suggestTagsEnabled,
    cooldownMinutes,
    junkText,
  ];
}
