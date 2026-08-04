import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/pixiv_settings.dart';
import '../../../domain/entities/pixiv_upload_task.dart';
import '../../../domain/repositories/secure_credential_store.dart';

/// Persists non-sensitive Pixiv options in SharedPreferences while delegating
/// [PixivSettings.cookie] and [PixivSettings.csrfToken] to
/// [SecureCredentialStore] (rules.md §2.4).
class PixivSettingsPreferences {
  PixivSettingsPreferences(this._prefs, this._secure);

  final SharedPreferences _prefs;
  final SecureCredentialStore _secure;

  static const _keyCookie = 'pixiv_cookie';
  static const _keyCsrf = 'pixiv_csrf';
  static const _keyProxy = 'pixiv_proxy';
  static const _keyCaptionPrefix = 'pixiv_caption_prefix';
  static const _keyDefaultTags = 'pixiv_default_tags';
  static const _keyXRestrict = 'pixiv_xrestrict_default';
  static const _keyAiType = 'pixiv_aitype_default';
  static const _keyRestrict = 'pixiv_restrict_default';
  static const _keyAllowComment = 'pixiv_allow_comment_default';
  static const _keyAllowTagEdit = 'pixiv_allow_tag_edit';
  static const _keySexual = 'pixiv_sexual_default';
  static const _keyAttributes = 'pixiv_attributes_default';
  static const _keyRatings = 'pixiv_ratings_default';
  static const _keyResponseAutoAccept = 'pixiv_response_auto_accept_default';
  static const _keyOriginal = 'pixiv_original_default';
  static const _keyStripMetadata = 'pixiv_strip_metadata';
  static const _keySuggestTags = 'pixiv_suggest_tags';
  static const _keyCooldown = 'pixiv_cooldown_minutes';
  static const _keyJunkText = 'pixiv_junk_text';

  Future<PixivSettings> load() async {
    String cookie;
    String csrfToken;
    try {
      cookie = await _secure.read(_keyCookie) ?? '';
      csrfToken = await _secure.read(_keyCsrf) ?? '';
    } catch (_) {
      // SecureStorage may be unavailable on some devices; fall back to empty
      // credentials instead of crashing the entire app startup.
      cookie = '';
      csrfToken = '';
    }
    final tagsJson = _prefs.getString(_keyDefaultTags);
    List<String> tags;
    try {
      tags = tagsJson != null
          ? (jsonDecode(tagsJson) as List).cast<String>()
          : PixivSettings.empty.defaultTags;
    } catch (_) {
      tags = PixivSettings.empty.defaultTags;
    }

    return PixivSettings(
      cookie: cookie,
      csrfToken: csrfToken,
      proxy: _prefs.getString(_keyProxy) ?? '',
      captionPrefix: _prefs.getString(_keyCaptionPrefix) ?? '',
      defaultTags: tags,
      xRestrictDefault: _enumOrDefault(
        _prefs.getString(_keyXRestrict),
        PixivXRestrict.values,
        PixivSettings.empty.xRestrictDefault,
      ),
      aiTypeDefault: _enumOrDefault(
        _prefs.getString(_keyAiType),
        PixivAiType.values,
        PixivSettings.empty.aiTypeDefault,
      ),
      restrictDefault: _enumOrDefault(
        _prefs.getString(_keyRestrict),
        PixivRestrict.values,
        PixivSettings.empty.restrictDefault,
      ),
      allowCommentDefault:
          _prefs.getBool(_keyAllowComment) ??
          PixivSettings.empty.allowCommentDefault,
      allowTagEdit: _prefs.getBool(_keyAllowTagEdit) ?? true,
      sexualDefault:
          _prefs.getBool(_keySexual) ?? PixivSettings.empty.sexualDefault,
      attributesDefault: _attributesFromJson(_prefs.getString(_keyAttributes)),
      ratingsDefault: _ratingsFromJson(_prefs.getString(_keyRatings)),
      responseAutoAcceptDefault:
          _prefs.getBool(_keyResponseAutoAccept) ??
          PixivSettings.empty.responseAutoAcceptDefault,
      originalDefault:
          _prefs.getBool(_keyOriginal) ?? PixivSettings.empty.originalDefault,
      stripMetadata: _prefs.getBool(_keyStripMetadata) ?? true,
      suggestTagsEnabled: _prefs.getBool(_keySuggestTags) ?? true,
      cooldownMinutes: _prefs.getInt(_keyCooldown) ?? 10,
      junkText: _prefs.getString(_keyJunkText) ?? '',
    );
  }

  Future<void> save(PixivSettings settings) async {
    await _secure.write(key: _keyCookie, value: settings.cookie);
    await _secure.write(key: _keyCsrf, value: settings.csrfToken);
    await _prefs.setString(_keyProxy, settings.proxy);
    await _prefs.setString(_keyCaptionPrefix, settings.captionPrefix);
    await _prefs.setString(_keyDefaultTags, jsonEncode(settings.defaultTags));
    await _prefs.setString(_keyXRestrict, settings.xRestrictDefault.name);
    await _prefs.setString(_keyAiType, settings.aiTypeDefault.name);
    await _prefs.setString(_keyRestrict, settings.restrictDefault.name);
    await _prefs.setBool(_keyAllowComment, settings.allowCommentDefault);
    await _prefs.setBool(_keyAllowTagEdit, settings.allowTagEdit);
    await _prefs.setBool(_keySexual, settings.sexualDefault);
    await _prefs.setString(
      _keyAttributes,
      _attributesToJson(settings.attributesDefault),
    );
    await _prefs.setString(
      _keyRatings,
      _ratingsToJson(settings.ratingsDefault),
    );
    await _prefs.setBool(
      _keyResponseAutoAccept,
      settings.responseAutoAcceptDefault,
    );
    await _prefs.setBool(_keyOriginal, settings.originalDefault);
    await _prefs.setBool(_keyStripMetadata, settings.stripMetadata);
    await _prefs.setBool(_keySuggestTags, settings.suggestTagsEnabled);
    await _prefs.setInt(_keyCooldown, settings.cooldownMinutes);
    await _prefs.setString(_keyJunkText, settings.junkText);
  }

  Future<void> clearCredentials() async {
    await _secure.delete(_keyCookie);
    await _secure.delete(_keyCsrf);
  }

  T _enumOrDefault<T extends Enum>(String? stored, List<T> values, T fallback) {
    if (stored == null) return fallback;
    for (final v in values) {
      if (v.name == stored) return v;
    }
    return fallback;
  }

  PixivAttributes _attributesFromJson(String? json) {
    if (json == null) return const PixivAttributes();
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      return PixivAttributes(
        bl: m['bl'] == true,
        yuri: m['yuri'] == true,
        furry: m['furry'] == true,
        lo: m['lo'] == true,
      );
    } catch (_) {
      return const PixivAttributes();
    }
  }

  String _attributesToJson(PixivAttributes a) {
    return jsonEncode({
      'bl': a.bl,
      'yuri': a.yuri,
      'furry': a.furry,
      'lo': a.lo,
    });
  }

  PixivRatings _ratingsFromJson(String? json) {
    if (json == null) return const PixivRatings();
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      return PixivRatings(
        violent: m['violent'] == true,
        antisocial: m['antisocial'] == true,
        drug: m['drug'] == true,
        religion: m['religion'] == true,
        thoughts: m['thoughts'] == true,
      );
    } catch (_) {
      return const PixivRatings();
    }
  }

  String _ratingsToJson(PixivRatings r) {
    return jsonEncode({
      'violent': r.violent,
      'antisocial': r.antisocial,
      'drug': r.drug,
      'religion': r.religion,
      'thoughts': r.thoughts,
    });
  }
}
