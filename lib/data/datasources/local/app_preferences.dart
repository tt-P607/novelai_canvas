import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/backend_mode.dart';

class AppPreferences {
  AppPreferences(this._preferences);

  final SharedPreferences _preferences;

  bool get onboardingCompleted =>
      _preferences.getBool(AppConstants.onboardingCompletedPreferenceKey) ??
      false;

  Future<void> setOnboardingCompleted(bool value) => _preferences.setBool(
    AppConstants.onboardingCompletedPreferenceKey,
    value,
  );

  String _endpointFor(String key, String fallback) {
    final value = _preferences.getString(key);
    if (value != null && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  /// Legacy single-value endpoint, kept only for one-time migration to the
  /// per-backend keys. New code must read [nativeEndpointBaseUrl] /
  /// [gatewayEndpointBaseUrl] instead.
  String get endpointBaseUrl {
    final current = _preferences.getString(
      AppConstants.endpointBaseUrlPreferenceKey,
    );
    if (current != null && current.trim().isNotEmpty) return current.trim();
    return _preferences.getString(AppConstants.gatewayBaseUrlPreferenceKey) ??
        '';
  }

  String get nativeEndpointBaseUrl =>
      _endpointFor(AppConstants.nativeEndpointBaseUrlPreferenceKey, '');

  Future<void> setNativeEndpointBaseUrl(String value) => _preferences.setString(
    AppConstants.nativeEndpointBaseUrlPreferenceKey,
    value.trim(),
  );

  String get gatewayEndpointBaseUrl =>
      _endpointFor(AppConstants.gatewayEndpointBaseUrlPreferenceKey, '');

  Future<void> setGatewayEndpointBaseUrl(String value) =>
      _preferences.setString(
        AppConstants.gatewayEndpointBaseUrlPreferenceKey,
        value.trim(),
      );

  BackendMode get backendMode {
    final stored = _preferences.getString(
      AppConstants.backendModePreferenceKey,
    );
    return BackendMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => BackendMode.native,
    );
  }

  Future<void> setBackendMode(BackendMode mode) =>
      _preferences.setString(AppConstants.backendModePreferenceKey, mode.name);

  bool get streamGenerationEnabled =>
      _preferences.getBool('stream_generation_enabled') ?? false;

  Future<void> setStreamGenerationEnabled(bool value) =>
      _preferences.setBool('stream_generation_enabled', value);

  /// Pause between consecutive queue tasks, in milliseconds.
  int get taskIntervalMs => _preferences.getInt('task_interval_ms') ?? 1000;

  Future<void> setTaskIntervalMs(int value) =>
      _preferences.setInt('task_interval_ms', value);

  /// Cached subscription tier. The tier itself is not a credential, so it may
  /// live in plain preferences for instant display on cold start.
  int? get subscriptionTier => _preferences.getInt('subscription_tier');

  DateTime? get subscriptionCheckedAt {
    final millis = _preferences.getInt('subscription_checked_at');
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> setSubscriptionTier(int tier, DateTime checkedAt) async {
    await _preferences.setInt('subscription_tier', tier);
    await _preferences.setInt(
      'subscription_checked_at',
      checkedAt.millisecondsSinceEpoch,
    );
  }

  /// Persisted generation parameters so the creation page survives a cold
  /// start. Stored as a single JSON blob to keep the preference namespace
  /// small and writes atomic. Vibe/character references are intentionally
  /// excluded — they carry large base64 payloads and are re-added by the user.
  static const _generationParamsKey = 'generation_params';

  Map<String, Object?> get generationParams {
    final raw = _preferences.getString(_generationParamsKey);
    if (raw == null || raw.isEmpty) return const {};
    final decoded = jsonDecode(raw);
    return decoded is Map
        ? decoded.map((k, v) => MapEntry(k.toString(), v))
        : const {};
  }

  Future<void> setGenerationParams(Map<String, Object?> params) =>
      _preferences.setString(_generationParamsKey, jsonEncode(params));
}
