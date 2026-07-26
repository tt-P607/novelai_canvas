import 'package:flutter/material.dart';

import 'glass/liquid_glass.dart';

/// Draggable, resizable in-page window for the prompt assistant.
///
/// Must be placed inside a [Stack]. Owns a [Positioned.fill] so the internal
/// [LayoutBuilder] never becomes the direct parent of a [Positioned], keeping
/// the [ParentDataWidget] contract intact.
class FloatingAssistantWindow extends StatefulWidget {
  const FloatingAssistantWindow({
    super.key,
    required this.child,
    required this.onMinimize,
    required this.onExpand,
  });

  final Widget child;
  final VoidCallback onMinimize;
  final VoidCallback onExpand;

  @override
  State<FloatingAssistantWindow> createState() =>
      _FloatingAssistantWindowState();
}

class _FloatingAssistantWindowState extends State<FloatingAssistantWindow> {
  Offset? _position;
  Size _size = const Size(340, 460);

  static const _minSize = Size(240, 300);

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final maxHeight = constraints.maxHeight;
          final width = _size.width.clamp(
            _minSize.width,
            (maxWidth - 16).clamp(_minSize.width, double.infinity),
          );
          final height = _size.height.clamp(
            _minSize.height,
            (maxHeight - 16).clamp(_minSize.height, double.infinity),
          );
          final position = _clamp(
            _position ?? Offset(maxWidth - width - 8, maxHeight - height - 96),
            maxWidth - width,
            maxHeight - height,
          );
          return Stack(
            children: [
              Positioned(
                left: position.dx,
                top: position.dy,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: Stack(
                    children: [
                      LiquidGlass(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _header(context, position),
                            Expanded(child: widget.child),
                          ],
                        ),
                      ),
                      // Bottom-right resize grip. Kept outside the glass so
                      // its hit area stays above the chat content.
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: _resizeGrip(context, Size(width, height)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, Offset resolvedPosition) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) {
        // Base the drag on the resolved position so the first drag does not
        // jump when no explicit position has been stored yet.
        setState(() => _position = resolvedPosition + details.delta);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 4, 0),
        child: Row(
          children: [
            const Icon(Icons.drag_indicator_rounded, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '提示词助手',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: '缩小为悬浮球',
              visualDensity: VisualDensity.compact,
              onPressed: widget.onMinimize,
              icon: const Icon(Icons.minimize_rounded, size: 18),
            ),
            IconButton(
              tooltip: '展开',
              visualDensity: VisualDensity.compact,
              onPressed: widget.onExpand,
              icon: const Icon(Icons.open_in_full_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resizeGrip(BuildContext context, Size resolvedSize) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) {
        // Base the resize on the resolved size so the first drag continues
        // smoothly from whatever the clamped size currently is.
        setState(() {
          _size = Size(
            resolvedSize.width + details.delta.dx,
            resolvedSize.height + details.delta.dy,
          );
        });
      },
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          Icons.south_east_rounded,
          size: 16,
          color: colors.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Offset _clamp(Offset value, double maxX, double maxY) => Offset(
    value.dx.clamp(0.0, maxX < 0 ? 0.0 : maxX),
    value.dy.clamp(0.0, maxY < 0 ? 0.0 : maxY),
  );
}
