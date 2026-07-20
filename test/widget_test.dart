import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_canvas/core/network/backend_mode.dart';
import 'package:novelai_canvas/domain/entities/app_settings.dart';
import 'package:novelai_canvas/domain/repositories/app_settings_repository.dart';
import 'package:novelai_canvas/presentation/controllers/app_settings_controller.dart';
import 'package:novelai_canvas/domain/repositories/secure_credential_store.dart';
import 'package:novelai_canvas/presentation/pages/onboarding_page.dart';

class _MemorySettingsRepository implements AppSettingsRepository {
  AppSettings value = const AppSettings.initial();

  @override
  Future<AppSettings> load() async => value;

  @override
  Future<void> save(AppSettings settings) async {
    value = settings;
  }
}

void main() {
  testWidgets('onboarding can enter with native backend', (tester) async {
    final repository = _MemorySettingsRepository();
    final controller = AppSettingsController(repository, repository.value);

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingPage(
          controller: controller,
          credentialStore: _MockCredentialStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NovelAI Canvas'), findsOneWidget);
    expect(find.text('进入绘境'), findsOneWidget);

    await tester.tap(find.text('进入绘境'));
    await tester.pumpAndSettle();

    expect(controller.settings.onboardingCompleted, isTrue);
    expect(controller.settings.backendMode, BackendMode.native);
  });
}

class _MockCredentialStore implements SecureCredentialStore {
  final Map<String, String> _data = {};

  @override
  Future<void> clear() async => _data.clear();

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write({required String key, required String value}) async =>
      _data[key] = value;
}
