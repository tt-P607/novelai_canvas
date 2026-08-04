import 'package:flutter/foundation.dart';

import '../../domain/entities/pixiv_settings.dart';
import '../../domain/repositories/pixiv_settings_repository.dart';

class PixivSettingsController extends ChangeNotifier {
  PixivSettingsController(this._repository, this.settings);

  final PixivSettingsRepository _repository;

  PixivSettings settings;

  Future<void> save(PixivSettings newSettings) async {
    settings = newSettings;
    await _repository.save(settings);
    notifyListeners();
  }

  Future<void> clearCredentials() async {
    settings = settings.copyWith(cookie: '', csrfToken: '');
    await _repository.clearCredentials();
    notifyListeners();
  }

  Future<void> reload() async {
    settings = await _repository.load();
    notifyListeners();
  }
}
