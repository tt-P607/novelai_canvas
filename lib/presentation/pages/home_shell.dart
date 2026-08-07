import 'dart:ui';

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

    return LiquidGlassBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: IndexedStack(index: _selectedIndex, children: pages),
        bottomNavigationBar: _LiquidTabBar(
          selectedIndex: _selectedIndex,
          onSelected: (index) => setState(() => _selectedIndex = index),
          destinations: _destinations,
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

/// Apple-style liquid tab bar: a floating pill with translucent glass, and a
/// selection pill that glides between items with a springy curve.
class _LiquidTabBar extends StatefulWidget {
  const _LiquidTabBar({
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<_Dest> destinations;

  @override
  State<_LiquidTabBar> createState() => _LiquidTabBarState();
}

class _LiquidTabBarState extends State<_LiquidTabBar> {
  /// Horizontal drag offset in logical px applied to the selection pill while
  /// the user is dragging; null means no drag in progress.
  double? _dragOffset;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final destinations = widget.destinations;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(24, 0, 24, 16),
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
          // Snap to the nearest tab centre, with velocity boosting the glide.
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: GlassSpec.thinBlurSigma,
              sigmaY: GlassSpec.thinBlurSigma,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: GlassSpec.body(colors),
                border: Border.all(
                  color: GlassSpec.rimTop(colors, opacity: 0.5),
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: GlassSpec.sheen()),
                child: SizedBox(
                  height: 72,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _itemWidth = constraints.maxWidth / destinations.length;
                      final itemWidth = _itemWidth!;
                      // While dragging the pill tracks the finger exactly; on
                      // release it springs back to the snapped position.
                      final dragging = _dragOffset != null;
                      final left = dragging
                          ? _dragOffset!
                          : widget.selectedIndex * itemWidth;
                      return Stack(
                        children: [
                          AnimatedPositioned(
                            duration: dragging
                                ? Duration.zero
                                : const Duration(milliseconds: 420),
                            curve: Curves.easeOutBack,
                            left: left + 6,
                            top: 6,
                            bottom: 6,
                            width: itemWidth - 12,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: colors.primary.withValues(alpha: 0.35),
                                ),
                              ),
                            ),
                          ),
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
            ),
          ),
        ),
      ),
    );
  }

  double? _itemWidth;
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
      borderRadius: BorderRadius.circular(24),
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
