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
    _settings = _applyEndpointForMode(
      _settings.copyWith(onboardingCompleted: true, backendMode: backendMode),
      backendMode,
      endpointBaseUrl.trim(),
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
    _settings = _applyEndpointForMode(
      _settings.copyWith(backendMode: backendMode),
      backendMode,
      endpointBaseUrl.trim(),
    );
    await _repository.save(_settings);
    notifyListeners();
  }

  /// Switches only the active backend, preserving each backend's saved URL.
  ///
  /// The settings page calls this the moment the user taps the segment button so
  /// the change takes effect without requiring a separate "save" tap.
  Future<void> switchBackendMode(BackendMode backendMode) async {
    _settings = _settings.copyWith(backendMode: backendMode);
    await _repository.save(_settings);
    notifyListeners();
  }

  static AppSettings _applyEndpointForMode(
    AppSettings base,
    BackendMode mode,
    String url,
  ) {
    if (mode == BackendMode.native) {
      return base.copyWith(nativeEndpointBaseUrl: url);
    }
    return base.copyWith(gatewayEndpointBaseUrl: url);
  }
}
