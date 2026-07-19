import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'domain/repositories/secure_credential_store.dart';
import 'presentation/controllers/app_settings_controller.dart';
import 'presentation/controllers/generation_controller.dart';
import 'presentation/controllers/history_controller.dart';
import 'presentation/controllers/image_tools_controller.dart';
import 'presentation/pages/home_shell.dart';
import 'presentation/pages/onboarding_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const NovelAiCanvasApp());
}

class NovelAiCanvasApp extends StatelessWidget {
  const NovelAiCanvasApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsController = getIt<AppSettingsController>();
    return ListenableBuilder(
      listenable: settingsController,
      builder: (context, _) {
        return MaterialApp(
          title: AppConstants.shortAppName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: settingsController.settings.onboardingCompleted
              ? HomeShell(
                  settingsController: settingsController,
                  credentialStore: getIt<SecureCredentialStore>(),
                  generationController: getIt<GenerationController>(),
                  historyController: getIt<HistoryController>(),
                  imageToolsController: getIt<ImageToolsController>(),
                )
              : OnboardingPage(controller: settingsController),
        );
      },
    );
  }
}
