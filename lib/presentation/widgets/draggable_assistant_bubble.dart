import 'package:flutter/material.dart';

/// A floating action button that can be dragged inside its parent and snaps to
/// the nearest horizontal edge when released.
///
/// Must be placed inside a [Stack]. The widget owns a [Positioned.fill] so the
/// internal [LayoutBuilder] never becomes the direct parent of a [Positioned],
/// which would break the [ParentDataWidget] contract and render an invisible
/// full-screen layer that swallows every gesture.
class DraggableAssistantBubble extends StatefulWidget {
  const DraggableAssistantBubble({
    super.key,
    required this.onPressed,
    this.size = 52,
    this.margin = 12,
    this.bottomInset = 96,
  });

  final VoidCallback onPressed;
  final double size;
  final double margin;

  /// Distance kept from the bottom edge for the initial resting position.
  final double bottomInset;

  @override
  State<DraggableAssistantBubble> createState() =>
      _DraggableAssistantBubbleState();
}

class _DraggableAssistantBubbleState extends State<DraggableAssistantBubble> {
  Offset? _offset;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final position = _resolve(constraints);
          return Stack(
            children: [
              Positioned(
                left: position.dx,
                top: position.dy,
                child: GestureDetector(
                  onPanUpdate: (details) => setState(
                    () =>
                        _offset = _clamp(position + details.delta, constraints),
                  ),
                  onPanEnd: (_) => setState(
                    () => _offset = Offset(
                      _snapX(position.dx, constraints),
                      position.dy,
                    ),
                  ),
                  child: FloatingActionButton.small(
                    heroTag: 'prompt-assistant-bubble',
                    tooltip: '打开提示词助手',
                    onPressed: widget.onPressed,
                    child: const Icon(Icons.auto_fix_high_rounded),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Offset _resolve(BoxConstraints constraints) {
    final current =
        _offset ??
        Offset(
          constraints.maxWidth - widget.size - widget.margin,
          constraints.maxHeight - widget.size - widget.bottomInset,
        );
    return _clamp(current, constraints);
  }

  Offset _clamp(Offset value, BoxConstraints constraints) => Offset(
    value.dx.clamp(widget.margin, _maxX(constraints)),
    value.dy.clamp(widget.margin, _maxY(constraints)),
  );

  double _snapX(double dx, BoxConstraints constraints) =>
      dx + widget.size / 2 < constraints.maxWidth / 2
      ? widget.margin
      : _maxX(constraints);

  double _maxX(BoxConstraints constraints) =>
      (constraints.maxWidth - widget.size - widget.margin).clamp(
        widget.margin,
        double.infinity,
      );

  double _maxY(BoxConstraints constraints) =>
      (constraints.maxHeight - widget.size - widget.margin).clamp(
        widget.margin,
        double.infinity,
      );
}
