import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/app_settings_repository.dart';
import '../datasources/local/app_preferences.dart';

class AppSettingsRepositoryImpl implements AppSettingsRepository {
  AppSettingsRepositoryImpl(this._preferences);

  final AppPreferences _preferences;

  @override
  Future<AppSettings> load() async {
    return AppSettings(
      onboardingCompleted: _preferences.onboardingCompleted,
      backendMode: _preferences.backendMode,
      gatewayBaseUrl: _preferences.gatewayBaseUrl,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    await Future.wait([
      _preferences.setOnboardingCompleted(settings.onboardingCompleted),
      _preferences.setBackendMode(settings.backendMode),
      _preferences.setGatewayBaseUrl(settings.gatewayBaseUrl),
    ]);
  }
}
