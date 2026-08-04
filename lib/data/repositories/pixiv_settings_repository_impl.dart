import '../datasources/local/pixiv_settings_preferences.dart';
import '../../domain/entities/pixiv_settings.dart';
import '../../domain/repositories/pixiv_settings_repository.dart';

class PixivSettingsRepositoryImpl implements PixivSettingsRepository {
  PixivSettingsRepositoryImpl(this._prefs);

  final PixivSettingsPreferences _prefs;

  @override
  Future<PixivSettings> load() => _prefs.load();

  @override
  Future<void> save(PixivSettings settings) => _prefs.save(settings);

  @override
  Future<void> clearCredentials() => _prefs.clearCredentials();
}
