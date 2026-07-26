import 'package:flutter/material.dart';

import '../../domain/entities/advanced_generation.dart';

/// Character placement picker.
///
/// Each cell carries the canvas aspect ratio so the grid reads as a miniature
/// of the render; the whole control is capped in height to stay compact in the
/// scrolling parameter list.
class CharacterPositionGrid extends StatelessWidget {
  const CharacterPositionGrid({
    super.key,
    required this.value,
    required this.onChanged,
    required this.canvasWidth,
    required this.canvasHeight,
    this.gridSize = 5,
    this.maxHeight = 180,
  });

  final CharacterPosition value;
  final ValueChanged<CharacterPosition> onChanged;
  final int canvasWidth;
  final int canvasHeight;
  final int gridSize;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selectedColumn = _index(value.x);
    final selectedRow = _index(value.y);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('画面位置', style: Theme.of(context).textTheme.labelSmall),
            const Spacer(),
            Text(
              '${_rowName(selectedRow)}${selectedColumn + 1}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: AspectRatio(
              aspectRatio: canvasWidth / canvasHeight,
              child: _grid(colors, selectedRow, selectedColumn),
            ),
          ),
        ),
      ],
    );
  }

  Widget _grid(ColorScheme colors, int selectedRow, int selectedColumn) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: List.generate(
              gridSize,
              (row) => Expanded(
                child: Row(
                  children: List.generate(
                    gridSize,
                    (column) => Expanded(
                      child: _cell(
                        colors,
                        row: row,
                        column: column,
                        selected:
                            row == selectedRow && column == selectedColumn,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _cell(
    ColorScheme colors, {
    required int row,
    required int column,
    required bool selected,
  }) => Semantics(
    button: true,
    selected: selected,
    label: '角色位置 ${_rowName(row)}${column + 1}',
    child: Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => onChanged(
          CharacterPosition(x: _coordinate(column), y: _coordinate(row)),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected
                ? colors.primary
                : colors.surfaceContainerLow.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
            ),
          ),
          child: Center(
            child: selected
                ? Icon(
                    Icons.person_pin_circle_rounded,
                    size: 16,
                    color: colors.onPrimary,
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );

  int _index(double coordinate) =>
      (((coordinate - 0.1) / 0.2).round()).clamp(0, gridSize - 1);

  double _coordinate(int index) => 0.1 + index * 0.2;

  String _rowName(int row) => String.fromCharCode(65 + row);
}
