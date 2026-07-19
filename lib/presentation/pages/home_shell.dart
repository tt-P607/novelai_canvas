import 'package:flutter/material.dart';

import '../../domain/repositories/secure_credential_store.dart';
import '../controllers/app_settings_controller.dart';
import '../controllers/generation_controller.dart';
import '../controllers/history_controller.dart';
import '../controllers/image_tools_controller.dart';
import 'creation_page.dart';
import 'history_page.dart';
import 'image_tools_page.dart';
import 'settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.settingsController,
    required this.credentialStore,
    required this.generationController,
    required this.historyController,
    required this.imageToolsController,
  });

  final AppSettingsController settingsController;
  final SecureCredentialStore credentialStore;
  final GenerationController generationController;
  final HistoryController historyController;
  final ImageToolsController imageToolsController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      CreationPage(controller: widget.generationController),
      HistoryPage(
        controller: widget.historyController,
        generationController: widget.generationController,
        onReuse: () => setState(() => _selectedIndex = 0),
      ),
      ImageToolsPage(controller: widget.imageToolsController),
      SettingsPage(
        controller: widget.settingsController,
        credentialStore: widget.credentialStore,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
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
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
