import 'package:flutter/foundation.dart';

import '../../core/network/backend_mode.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/app_settings_repository.dart';

class AppSettingsController extends ChangeNotifier {
  AppSettingsController(this._repository, this._settings);

  final AppSettingsRepository _repository;
  AppSettings _settings;

  AppSettings get settings => _settings;

  Future<void> completeOnboarding({
    required BackendMode backendMode,
    required String endpointBaseUrl,
  }) async {
    _settings = _settings.copyWith(
      onboardingCompleted: true,
      backendMode: backendMode,
      endpointBaseUrl: endpointBaseUrl.trim(),
    );
    await _repository.save(_settings);
    notifyListeners();
  }

  Future<void> applyImportedSettings(AppSettings settings) async {
    _settings = settings.copyWith(onboardingCompleted: true);
    await _repository.save(_settings);
    notifyListeners();
  }

  Future<void> updateBackend({
    required BackendMode backendMode,
    required String endpointBaseUrl,
  }) async {
    _settings = _settings.copyWith(
      backendMode: backendMode,
      endpointBaseUrl: endpointBaseUrl.trim(),
    );
    await _repository.save(_settings);
    notifyListeners();
  }
}
