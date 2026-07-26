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

  String get endpointBaseUrl {
    final current = _preferences.getString(
      AppConstants.endpointBaseUrlPreferenceKey,
    );
    if (current != null && current.trim().isNotEmpty) return current.trim();
    return _preferences.getString(AppConstants.gatewayBaseUrlPreferenceKey) ??
        '';
  }

  Future<void> setEndpointBaseUrl(String value) => _preferences.setString(
    AppConstants.endpointBaseUrlPreferenceKey,
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
}
