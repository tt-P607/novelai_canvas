import 'package:flutter/material.dart';

import 'glass/liquid_glass.dart';

/// Draggable in-page window for the prompt assistant.
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

  static const _size = Size(340, 460);

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final maxHeight = constraints.maxHeight;
          final width = _size.width.clamp(0.0, maxWidth - 16);
          final height = _size.height.clamp(0.0, maxHeight - 16);
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
                  child: LiquidGlass(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _header(context, position),
                        Expanded(child: widget.child),
                      ],
                    ),
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

  Offset _clamp(Offset value, double maxX, double maxY) => Offset(
    value.dx.clamp(0.0, maxX < 0 ? 0.0 : maxX),
    value.dy.clamp(0.0, maxY < 0 ? 0.0 : maxY),
  );
}
