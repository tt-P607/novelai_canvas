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
    final storedUrl = _preferences.endpointBaseUrl.trim();
    return AppSettings(
      onboardingCompleted: _preferences.onboardingCompleted,
      backendMode: mode,
      endpointBaseUrl: storedUrl.isEmpty && mode == BackendMode.native
          ? AppConstants.nativeBaseUrl
          : storedUrl,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    await Future.wait([
      _preferences.setOnboardingCompleted(settings.onboardingCompleted),
      _preferences.setBackendMode(settings.backendMode),
      _preferences.setEndpointBaseUrl(settings.endpointBaseUrl),
    ]);
  }
}
