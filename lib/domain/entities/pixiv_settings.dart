import 'package:equatable/equatable.dart';

/// All user-configurable options for Pixiv publishing.
///
/// Sensitive fields [cookie] and [csrfToken] must be persisted through
/// [SecureCredentialStore] only — never SharedPreferences, SQLite, backups or
/// logs (see rules.md §2.4).
class PixivSettings extends Equatable {
  const PixivSettings({
    required this.cookie,
    required this.csrfToken,
    required this.proxy,
    required this.captionPrefix,
    required this.defaultTags,
    required this.r18Default,
    required this.allowTagEdit,
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
  final bool r18Default;
  final bool allowTagEdit;
  final bool stripMetadata;
  final bool suggestTagsEnabled;
  final int cooldownMinutes;
  final String junkText;

  bool get hasCredentials =>
      cookie.trim().isNotEmpty && csrfToken.trim().isNotEmpty;

  PixivSettings copyWith({
    String? cookie,
    String? csrfToken,
    String? proxy,
    String? captionPrefix,
    List<String>? defaultTags,
    bool? r18Default,
    bool? allowTagEdit,
    bool? stripMetadata,
    bool? suggestTagsEnabled,
    int? cooldownMinutes,
    String? junkText,
  }) {
    return PixivSettings(
      cookie: cookie ?? this.cookie,
      csrfToken: csrfToken ?? this.csrfToken,
      proxy: proxy ?? this.proxy,
      captionPrefix: captionPrefix ?? this.captionPrefix,
      defaultTags: defaultTags ?? this.defaultTags,
      r18Default: r18Default ?? this.r18Default,
      allowTagEdit: allowTagEdit ?? this.allowTagEdit,
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
    r18Default: false,
    allowTagEdit: true,
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
    r18Default,
    allowTagEdit,
    stripMetadata,
    suggestTagsEnabled,
    cooldownMinutes,
    junkText,
  ];
}
