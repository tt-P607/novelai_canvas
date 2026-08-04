import '../entities/pixiv_settings.dart';

/// Loads and persists [PixivSettings]. Credentials are delegated to
/// [SecureCredentialStore] while non-sensitive options use SharedPreferences.
abstract interface class PixivSettingsRepository {
  Future<PixivSettings> load();

  Future<void> save(PixivSettings settings);

  Future<void> clearCredentials();
}
