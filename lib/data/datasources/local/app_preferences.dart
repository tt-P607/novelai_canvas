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
}
