import 'package:flutter/material.dart';

import '../../domain/repositories/secure_credential_store.dart';
import '../controllers/app_settings_controller.dart';
import 'placeholder_feature_page.dart';
import 'settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.settingsController,
    required this.credentialStore,
  });

  final AppSettingsController settingsController;
  final SecureCredentialStore credentialStore;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const PlaceholderFeaturePage(
        icon: Icons.auto_awesome_rounded,
        title: '创作',
        description: '统一编排文生图、图生图、局部重绘与高级 NovelAI 参数。',
        nextStage: '大阶段三',
      ),
      const PlaceholderFeaturePage(
        icon: Icons.photo_library_rounded,
        title: '作品',
        description: '集中查看生成历史、参数快照、收藏与本地图片。',
        nextStage: '大阶段三',
      ),
      const PlaceholderFeaturePage(
        icon: Icons.build_circle_rounded,
        title: '工具',
        description: 'Vibe、角色参考、放大、标签建议与六种导演工具将在这里汇集。',
        nextStage: '大阶段四',
      ),
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
