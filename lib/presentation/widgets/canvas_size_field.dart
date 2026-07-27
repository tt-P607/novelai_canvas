import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Official canvas presets, grouped the way NovelAI presents them.
class CanvasPreset {
  const CanvasPreset(this.label, this.width, this.height);

  final String label;
  final int width;
  final int height;

  String get key => '${width}x$height';
}

const _normalPresets = [
  CanvasPreset('Portrait', 832, 1216),
  CanvasPreset('Landscape', 1216, 832),
  CanvasPreset('Square', 1024, 1024),
];

const _largePresets = [
  CanvasPreset('Portrait', 1024, 1536),
  CanvasPreset('Landscape', 1536, 1024),
  CanvasPreset('Square', 1472, 1472),
];

/// Canvas picker mirroring the official layout: a preset card next to live
/// width and height fields.
///
/// Editing a dimension applies immediately and flips the preset to "Custom" —
/// there is no separate confirm step, so the numbers on screen are always the
/// numbers that will be sent.
class CanvasSizeField extends StatelessWidget {
  const CanvasSizeField({
    super.key,
    required this.width,
    required this.height,
    required this.widthController,
    required this.heightController,
    required this.onChanged,
  });

  final int width;
  final int height;
  final TextEditingController widthController;
  final TextEditingController heightController;
  final void Function(int width, int height) onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('画幅', style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            Text(
              _isLarge ? '大图 · 消耗 Anlas' : '标准 · Opus 免费',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: _isLarge ? colors.tertiary : colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(flex: 5, child: _presetCard(context)),
            const SizedBox(width: 10),
            Expanded(flex: 3, child: _dimensionField(widthController, '宽')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: colors.onSurfaceVariant,
              ),
            ),
            Expanded(flex: 3, child: _dimensionField(heightController, '高')),
          ],
        ),
      ],
    );
  }

  bool get _isLarge => width * height > 1048576;

  CanvasPreset? get _activePreset {
    for (final preset in [..._normalPresets, ..._largePresets]) {
      if (preset.width == width && preset.height == height) return preset;
    }
    return null;
  }

  Widget _presetCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = _activePreset;
    final label = active != null
        ? (_largePresets.contains(active)
              ? 'Large ${active.label}'
              : active.label)
        : 'Custom';
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showPresetSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Icon(
                Icons.unfold_more_rounded,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPresetSheet(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = _activePreset;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colors.surface,
      builder: (sheetContext) {
        Widget sectionHeader(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              letterSpacing: 1.1,
            ),
          ),
        );
        Widget presetTile(CanvasPreset preset, {bool isLarge = false}) {
          final isSelected = active?.key == preset.key;
          final displayName = isLarge ? 'Large ${preset.label}' : preset.label;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Material(
              color: isSelected
                  ? colors.primaryContainer.withValues(alpha: 0.5)
                  : colors.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  onChanged(preset.width, preset.height);
                  Navigator.pop(sheetContext);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? colors.primary.withValues(alpha: 0.6)
                          : colors.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? colors.onPrimaryContainer
                                        : colors.onSurface,
                                  ),
                            ),
                            Text(
                              '${preset.width} × ${preset.height}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle_rounded,
                          size: 22,
                          color: colors.primary,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    Text(
                      '选择画幅',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    sectionHeader('NORMAL'),
                    ..._normalPresets.map((p) => presetTile(p)),
                    sectionHeader('LARGE'),
                    ..._largePresets.map((p) => presetTile(p, isLarge: true)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dimensionField(TextEditingController field, String label) =>
      TextField(
        controller: field,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 14,
          ),
        ),
        onChanged: (_) => _applyFields(),
      );

  /// Applies edits only once both fields hold a usable value, so intermediate
  /// keystrokes never clamp the number the user is still typing.
  void _applyFields() {
    final parsedWidth = int.tryParse(widthController.text);
    final parsedHeight = int.tryParse(heightController.text);
    if (parsedWidth == null || parsedHeight == null) return;
    if (parsedWidth < 64 || parsedHeight < 64) return;
    if (parsedWidth > 1600 || parsedHeight > 1600) return;
    onChanged(parsedWidth, parsedHeight);
  }
}
