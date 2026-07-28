import '../../core/constants/app_constants.dart';
import '../../core/network/backend_mode.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/app_settings_repository.dart';
import '../datasources/local/app_preferences.dart';

class AppSettingsRepositoryImpl implements AppSettingsRepository {
  AppSettingsRepositoryImpl(this._preferences);

  final AppPreferences _preferences;

  @override
  Future<AppSettings> load() async {
    final mode = _preferences.backendMode;
    var nativeUrl = _preferences.nativeEndpointBaseUrl.trim();
    var gatewayUrl = _preferences.gatewayEndpointBaseUrl.trim();
    // One-time migration from the legacy single-value preference: assign the
    // old shared URL to whichever backend was active when it was stored.
    if (nativeUrl.isEmpty && gatewayUrl.isEmpty) {
      final legacy = _preferences.endpointBaseUrl.trim();
      if (legacy.isNotEmpty) {
        if (mode == BackendMode.native) {
          nativeUrl = legacy;
        } else {
          gatewayUrl = legacy;
        }
      }
    }
    if (nativeUrl.isEmpty && mode == BackendMode.native) {
      nativeUrl = AppConstants.nativeBaseUrl;
    }
    return AppSettings(
      onboardingCompleted: _preferences.onboardingCompleted,
      backendMode: mode,
      nativeEndpointBaseUrl: nativeUrl,
      gatewayEndpointBaseUrl: gatewayUrl,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    await Future.wait([
      _preferences.setOnboardingCompleted(settings.onboardingCompleted),
      _preferences.setBackendMode(settings.backendMode),
      _preferences.setNativeEndpointBaseUrl(settings.nativeEndpointBaseUrl),
      _preferences.setGatewayEndpointBaseUrl(settings.gatewayEndpointBaseUrl),
    ]);
  }
}
