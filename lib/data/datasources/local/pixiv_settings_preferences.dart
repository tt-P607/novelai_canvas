import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/pixiv_settings.dart';
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
  static const _keyR18Default = 'pixiv_r18_default';
  static const _keyAllowTagEdit = 'pixiv_allow_tag_edit';
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
      r18Default: _prefs.getBool(_keyR18Default) ?? false,
      allowTagEdit: _prefs.getBool(_keyAllowTagEdit) ?? true,
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
    await _prefs.setBool(_keyR18Default, settings.r18Default);
    await _prefs.setBool(_keyAllowTagEdit, settings.allowTagEdit);
    await _prefs.setBool(_keyStripMetadata, settings.stripMetadata);
    await _prefs.setBool(_keySuggestTags, settings.suggestTagsEnabled);
    await _prefs.setInt(_keyCooldown, settings.cooldownMinutes);
    await _prefs.setString(_keyJunkText, settings.junkText);
  }

  Future<void> clearCredentials() async {
    await _secure.delete(_keyCookie);
    await _secure.delete(_keyCsrf);
  }
}
