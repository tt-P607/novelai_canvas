import 'dart:ui';

import 'package:flutter/material.dart';

import '../../domain/repositories/secure_credential_store.dart';
import '../controllers/app_settings_controller.dart';
import '../controllers/data_management_controller.dart';
import '../controllers/generation_controller.dart';
import '../controllers/history_controller.dart';
import '../controllers/image_tools_controller.dart';
import '../controllers/llm_assistant_settings_controller.dart';
import '../../core/di/injection.dart';
import '../controllers/pixiv_settings_controller.dart';
import '../controllers/pixiv_upload_controller.dart';
import '../controllers/prompt_assistant_controller.dart';
import '../widgets/glass/liquid_glass.dart';
import 'creation_page.dart';
import 'history_page.dart';
import 'image_tools_page.dart';
import 'pixiv_upload_page.dart';
import 'settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.settingsController,
    required this.credentialStore,
    required this.generationController,
    required this.historyController,
    required this.imageToolsController,
    required this.promptAssistantController,
    required this.llmSettingsController,
    required this.dataManagementController,
  });

  final AppSettingsController settingsController;
  final SecureCredentialStore credentialStore;
  final GenerationController generationController;
  final HistoryController historyController;
  final ImageToolsController imageToolsController;
  final PromptAssistantController promptAssistantController;
  final LlmAssistantSettingsController llmSettingsController;
  final DataManagementController dataManagementController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      CreationPage(
        controller: widget.generationController,
        promptAssistantController: widget.promptAssistantController,
        llmSettingsController: widget.llmSettingsController,
        onOpenImageTools: (path) async {
          await widget.imageToolsController.setSourceImage(path);
          if (mounted) setState(() => _selectedIndex = 2);
        },
      ),
      HistoryPage(
        controller: widget.historyController,
        generationController: widget.generationController,
        onReuse: () => setState(() => _selectedIndex = 0),
        onPublishToPixiv: (path) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PixivUploadPage(
              uploadController: getIt<PixivUploadController>(),
              settingsController: getIt<PixivSettingsController>(),
              initialImagePaths: [path],
            ),
          ),
        ),
      ),
      ImageToolsPage(
        controller: widget.imageToolsController,
        generationController: widget.generationController,
      ),
      PixivUploadPage(
        uploadController: getIt<PixivUploadController>(),
        settingsController: getIt<PixivSettingsController>(),
        initialImagePaths: const [],
      ),
      SettingsPage(
        controller: widget.settingsController,
        credentialStore: widget.credentialStore,
        dataManagementController: widget.dataManagementController,
        llmSettingsController: widget.llmSettingsController,
      ),
    ];

    return LiquidGlassBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: IndexedStack(index: _selectedIndex, children: pages),
        bottomNavigationBar: _glassNavigationBar(),
      ),
    );
  }

  /// The bar floats above page content, so it blurs the scrolling body instead
  /// of painting an opaque strip over it.
  Widget _glassNavigationBar() => ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: GlassSpec.blurSigma,
        sigmaY: GlassSpec.blurSigma,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome_rounded),
              label: '创作',
            ),
            NavigationDestination(
              icon: Icon(Icons.photo_library_outlined),
              selectedIcon: Icon(Icons.photo_library_rounded),
              label: '作品',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: '工具',
            ),
            NavigationDestination(
              icon: Icon(Icons.upload_outlined),
              selectedIcon: Icon(Icons.upload_rounded),
              label: 'Pixiv',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: '设置',
            ),
          ],
        ),
      ),
    ),
  );
}
