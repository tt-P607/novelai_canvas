import 'package:flutter/material.dart';

import '../../domain/repositories/secure_credential_store.dart';
import '../controllers/app_settings_controller.dart';
import '../controllers/data_management_controller.dart';
import '../controllers/generation_controller.dart';
import '../controllers/history_controller.dart';
import '../controllers/image_tools_controller.dart';
import '../controllers/llm_assistant_settings_controller.dart';
import '../controllers/prompt_assistant_controller.dart';
import '../widgets/glass/liquid_glass.dart';
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

  /// Height of the floating tab bar so the shell can animate it off-screen
  /// while the keyboard is open.
  static const _floatingBarHeight = 64.0;

  static const _destinations = <_Dest>[
    _Dest(Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, '创作'),
    _Dest(Icons.photo_library_outlined, Icons.photo_library_rounded, '作品'),
    _Dest(Icons.grid_view_outlined, Icons.grid_view_rounded, '工具'),
    _Dest(Icons.settings_outlined, Icons.settings_rounded, '设置'),
  ];

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
      ),
      ImageToolsPage(
        controller: widget.imageToolsController,
        generationController: widget.generationController,
      ),
      SettingsPage(
        controller: widget.settingsController,
        credentialStore: widget.credentialStore,
        dataManagementController: widget.dataManagementController,
        llmSettingsController: widget.llmSettingsController,
      ),
    ];

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return LiquidGlassBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(index: _selectedIndex, children: pages),
            ),
            // Keep the capsule clear of the on-screen keyboard, and float it
            // above the bottom safe area with a comfortable margin.
            AnimatedPositioned(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              left: 16,
              right: 16,
              bottom: keyboardInset > 0
                  ? -_floatingBarHeight
                  : (bottomInset <= 0 ? 24.0 : bottomInset + 16),
              child: _DragTabBar(
                selectedIndex: _selectedIndex,
                onSelected: (index) => setState(() => _selectedIndex = index),
                destinations: _destinations,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dest {
  const _Dest(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Floating liquid-glass capsule docked above the bottom safe area. Dragging
/// moves the selection pill with the finger; releasing snaps it to the nearest
/// tab.
class _DragTabBar extends StatefulWidget {
  const _DragTabBar({
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<_Dest> destinations;

  @override
  State<_DragTabBar> createState() => _DragTabBarState();
}

class _DragTabBarState extends State<_DragTabBar> {
  /// Horizontal drag offset in logical px applied to the selection pill while
  /// the user is dragging; null means no drag in progress.
  double? _dragOffset;

  double? _itemWidth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final destinations = widget.destinations;
    return LiquidGlass(
      radius: 18,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) =>
            setState(() => _dragOffset = widget.selectedIndex * 1.0),
        onHorizontalDragUpdate: (details) {
          setState(() {
            _dragOffset =
                (_dragOffset ?? widget.selectedIndex.toDouble()) +
                details.delta.dx;
          });
        },
        onHorizontalDragEnd: (details) {
          final itemWidth = _itemWidth;
          if (itemWidth == null || itemWidth <= 0) {
            setState(() => _dragOffset = null);
            return;
          }
          // Snap to the nearest tab centre, with velocity boosting the
          // glide just like a natural swipe.
          final base =
              (_dragOffset ?? widget.selectedIndex.toDouble()) / itemWidth;
          final velocityBoost = details.primaryVelocity != null
              ? (details.primaryVelocity! / 800)
              : 0.0;
          final target = (base + velocityBoost).round().clamp(
            0,
            destinations.length - 1,
          );
          setState(() => _dragOffset = null);
          if (target != widget.selectedIndex) widget.onSelected(target);
        },
        onHorizontalDragCancel: () => setState(() => _dragOffset = null),
        child: SizedBox(
          height: _HomeShellState._floatingBarHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _itemWidth = constraints.maxWidth / destinations.length;
              final itemWidth = _itemWidth!;
              final dragging = _dragOffset != null;
              final left = dragging
                  ? _dragOffset!
                  : widget.selectedIndex * itemWidth;
              return Stack(
                children: [
                  // Sliding selection pill.
                  AnimatedPositioned(
                    duration: dragging
                        ? Duration.zero
                        : const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    left: left + 8,
                    top: 8,
                    bottom: 8,
                    width: itemWidth - 16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  // Items sit above the pill.
                  Row(
                    children: [
                      for (var i = 0; i < destinations.length; i++)
                        Expanded(
                          child: _TabItem(
                            dest: destinations[i],
                            selected: i == widget.selectedIndex,
                            onTap: () => widget.onSelected(i),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.dest,
    required this.selected,
    required this.onTap,
  });

  final _Dest dest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: selected ? 1 : 0.62,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? dest.selectedIcon : dest.icon,
              size: 26,
              color: selected ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              dest.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected ? colors.primary : colors.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
