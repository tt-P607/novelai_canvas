import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../core/backup/app_backup_service.dart';
import '../../domain/repositories/secure_credential_store.dart';
import 'app_settings_controller.dart';
import 'history_controller.dart';
import 'llm_assistant_settings_controller.dart';

class DataManagementController extends ChangeNotifier {
  DataManagementController({
    required AppBackupService backupService,
    required SecureCredentialStore credentialStore,
    required AppSettingsController appSettingsController,
    required LlmAssistantSettingsController llmSettingsController,
    required HistoryController historyController,
  }) : _backupService = backupService,
       _credentialStore = credentialStore,
       _appSettingsController = appSettingsController,
       _llmSettingsController = llmSettingsController,
       _historyController = historyController;

  final AppBackupService _backupService;
  final SecureCredentialStore _credentialStore;
  final AppSettingsController _appSettingsController;
  final LlmAssistantSettingsController _llmSettingsController;
  final HistoryController _historyController;

  bool busy = false;
  String? lastExportPath;
  String? errorMessage;

  Future<String?> exportBackup() async {
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      lastExportPath = await _backupService.exportToFile();
      return lastExportPath;
    } catch (error) {
      errorMessage = error.toString();
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<int?> importBackup({bool replaceExistingHistory = false}) async {
    final selection = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    final path = selection?.path;
    if (path == null) return null;

    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _backupService.importFromFile(
        path,
        replaceExistingHistory: replaceExistingHistory,
      );
      final appSettings = await _backupService.loadAppSettings();
      final llmSettings = await _backupService.loadLlmSettings();
      await _appSettingsController.applyImportedSettings(appSettings);
      await _llmSettingsController.applyImportedSettings(llmSettings);
      await _historyController.load();
      return result.importedHistoryCount;
    } catch (error) {
      errorMessage = error.toString();
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> clearCredentials() async {
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _credentialStore.clear();
    } catch (error) {
      errorMessage = error.toString();
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
