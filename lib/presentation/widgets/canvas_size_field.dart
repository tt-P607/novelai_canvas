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

/// Canvas picker mirroring the official layout: a preset dropdown next to live
/// width and height fields.
///
/// Editing a dimension applies immediately and flips the dropdown to
/// "Custom" — there is no separate confirm step, so the numbers on screen are
/// always the numbers that will be sent.
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
            Expanded(flex: 5, child: _presetDropdown(context)),
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

  Widget _presetDropdown(BuildContext context) {
    final active = _activePreset;
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: active?.key ?? 'custom',
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      items: [
        _header(context, 'NORMAL'),
        ..._normalPresets.map(_presetItem),
        _header(context, 'LARGE'),
        ..._largePresets.map(_presetItem),
        const DropdownMenuItem(value: 'custom', child: Text('Custom')),
      ],
      selectedItemBuilder: (context) => [
        const SizedBox.shrink(),
        ..._normalPresets.map((preset) => _selectedLabel(preset.label)),
        const SizedBox.shrink(),
        ..._largePresets.map(
          (preset) => _selectedLabel('Large ${preset.label}'),
        ),
        _selectedLabel('Custom'),
      ],
      onChanged: (value) {
        if (value == null || value == 'custom') return;
        final parts = value.split('x');
        onChanged(int.parse(parts[0]), int.parse(parts[1]));
      },
    );
  }

  DropdownMenuItem<String> _header(BuildContext context, String text) =>
      DropdownMenuItem(
        enabled: false,
        value: '#$text',
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 1.1,
          ),
        ),
      );

  DropdownMenuItem<String> _presetItem(CanvasPreset preset) => DropdownMenuItem(
    value: preset.key,
    child: Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text('${preset.label} (${preset.width}x${preset.height})'),
    ),
  );

  Widget _selectedLabel(String text) =>
      Align(alignment: Alignment.centerLeft, child: Text(text));

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
