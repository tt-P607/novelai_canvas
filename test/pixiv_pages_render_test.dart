import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:novelai_canvas/data/api/pixiv/pixiv_api_service.dart';
import 'package:novelai_canvas/data/datasources/local/pixiv_settings_preferences.dart';
import 'package:novelai_canvas/data/repositories/pixiv_settings_repository_impl.dart';
import 'package:novelai_canvas/data/repositories/pixiv_upload_repository_impl.dart';
import 'package:novelai_canvas/core/queue/pixiv_upload_queue.dart';
import 'package:novelai_canvas/core/storage/pixiv_image_cloaker.dart';
import 'package:novelai_canvas/domain/entities/pixiv_settings.dart';
import 'package:novelai_canvas/domain/repositories/secure_credential_store.dart';
import 'package:novelai_canvas/presentation/controllers/pixiv_settings_controller.dart';
import 'package:novelai_canvas/presentation/controllers/pixiv_upload_controller.dart';
import 'package:novelai_canvas/presentation/pages/pixiv_upload_page.dart';
import 'package:novelai_canvas/presentation/pages/pixiv_queue_page.dart';
import 'package:novelai_canvas/presentation/pages/pixiv_settings_page.dart';

class _MemorySecureStore implements SecureCredentialStore {
  final Map<String, String> _data = {};
  @override
  Future<void> write({required String key, required String value}) async =>
      _data[key] = value;
  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> delete(String key) async => _data.remove(key);
  @override
  Future<void> clear() async => _data.clear();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  (PixivSettingsController, PixivUploadController) buildControllers() {
    final settingsRepo = PixivSettingsRepositoryImpl(
      PixivSettingsPreferences(prefs, _MemorySecureStore()),
    );
    final uploadRepo = PixivUploadRepositoryImpl(PixivApiService());
    final settingsController = PixivSettingsController(
      settingsRepo,
      PixivSettings.empty,
    );
    final uploadController = PixivUploadController(
      PixivUploadQueue(
        uploadRepository: uploadRepo,
        settingsRepository: settingsRepo,
        cloaker: PixivImageCloaker(),
      ),
    );
    return (settingsController, uploadController);
  }

  ThemeData buildTestTheme() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.transparent,
  );

  testWidgets('PixivUploadPage renders without throwing', (tester) async {
    final (settingsController, uploadController) = buildControllers();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTestTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PixivUploadPage(
                      uploadController: uploadController,
                      settingsController: settingsController,
                      initialImagePaths: const [],
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('发布到 Pixiv'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PixivQueuePage renders without throwing', (tester) async {
    final (_, uploadController) = buildControllers();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTestTheme(),
        home: PixivQueuePage(controller: uploadController),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('上传队列'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PixivSettingsPage renders without throwing', (tester) async {
    final (settingsController, _) = buildControllers();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTestTheme(),
        home: PixivSettingsPage(controller: settingsController),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pixiv 设置'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
