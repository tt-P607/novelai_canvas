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

  String get gatewayBaseUrl =>
      _preferences.getString(AppConstants.gatewayBaseUrlPreferenceKey) ?? '';

  Future<void> setGatewayBaseUrl(String value) => _preferences.setString(
    AppConstants.gatewayBaseUrlPreferenceKey,
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
}
