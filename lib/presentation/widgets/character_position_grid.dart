import 'package:flutter/material.dart';

import '../../domain/entities/advanced_generation.dart';

/// Character placement picker.
///
/// The grid mirrors the configured canvas ratio so a cell on screen sits where
/// the character will appear in the render; a fixed square would misrepresent
/// portrait and landscape layouts.
class CharacterPositionGrid extends StatelessWidget {
  const CharacterPositionGrid({
    super.key,
    required this.value,
    required this.onChanged,
    required this.canvasWidth,
    required this.canvasHeight,
    this.gridSize = 5,
  });

  final CharacterPosition value;
  final ValueChanged<CharacterPosition> onChanged;
  final int canvasWidth;
  final int canvasHeight;
  final int gridSize;

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
            Text('画面位置', style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            Text(
              '${_rowName(selectedRow)}${selectedColumn + 1}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AspectRatio(
          aspectRatio: canvasWidth / canvasHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: gridSize * gridSize,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridSize,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                ),
                itemBuilder: (context, index) {
                  final row = index ~/ gridSize;
                  final column = index % gridSize;
                  final selected =
                      row == selectedRow && column == selectedColumn;
                  return Semantics(
                    button: true,
                    selected: selected,
                    label: '角色位置 ${_rowName(row)}${column + 1}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onChanged(
                        CharacterPosition(
                          x: _coordinate(column),
                          y: _coordinate(row),
                        ),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          color: selected
                              ? colors.primary
                              : colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? colors.primary
                                : colors.outlineVariant,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: colors.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: selected
                              ? Icon(
                                  Icons.person_pin_circle_rounded,
                                  size: 22,
                                  color: colors.onPrimary,
                                )
                              : Text(
                                  '${_rowName(row)}${column + 1}',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '网格按当前画幅 $canvasWidth × $canvasHeight 显示，点击即可指定角色中心位置。',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }

  int _index(double coordinate) =>
      (((coordinate - 0.1) / 0.2).round()).clamp(0, gridSize - 1);

  double _coordinate(int index) => 0.1 + index * 0.2;

  String _rowName(int row) => String.fromCharCode(65 + row);
}
