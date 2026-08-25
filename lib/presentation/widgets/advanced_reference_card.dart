import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/entities/advanced_generation.dart';
import '../../domain/entities/generation_task.dart';
import '../controllers/generation_controller.dart';
import 'anlas_icon.dart';
import 'character_position_grid.dart';
import 'glass/liquid_glass.dart';

/// Vibe transfer, V4.5 character references and multi-character coordinates.
class AdvancedReferenceCard extends StatelessWidget {
  const AdvancedReferenceCard({
    super.key,
    required this.controller,
    required this.onAddVibe,
    required this.onAddCharacterReference,
    required this.onEncodeVibe,
    required this.onExportVibe,
  });

  final GenerationController controller;
  final VoidCallback onAddVibe;
  final VoidCallback onAddCharacterReference;

  /// Called when the user taps the encode button on a vibe tile.
  final void Function(int index) onEncodeVibe;

  /// Called when the user taps the download button on a vibe tile.
  final void Function(int index) onExportVibe;

  @override
  Widget build(BuildContext context) {
    // Character reference is only offered by the native V4.5 endpoint; V5
    // rejects both Vibe and character references upstream, so their tiles are
    // hidden while Vibe and multi-character stay usable in every other mode.
    final showCharacterReference =
        controller.mode != GenerationMode.inpaint &&
        controller.supportsCharacterReference;
    final showVibe = controller.supportsVibe;
    return LiquidGlass(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('高级参考', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('Vibe 控制风格；角色参考仅支持原生 V4.5；V5 不支持 Vibe 与角色参考。'),
          const Divider(height: 28),
          if (showVibe) ...[
            _sectionHeader(
              title: 'Vibe Transfer',
              icon: Icons.add_photo_alternate_outlined,
              onPressed: onAddVibe,
            ),
            ...controller.vibeReferences.indexed.map(
              (entry) => _VibeTile(
                index: entry.$1,
                reference: entry.$2,
                controller: controller,
                onEncode: () => onEncodeVibe(entry.$1),
                onExport: () => onExportVibe(entry.$1),
              ),
            ),
          ],
          if (showCharacterReference) ...[
            const Divider(height: 28),
            _sectionHeader(
              title: 'V4.5 角色参考',
              icon: Icons.person_add_alt_rounded,
              onPressed: onAddCharacterReference,
            ),
            ...controller.characterReferences.indexed.map(
              (entry) => _CharacterReferenceTile(
                index: entry.$1,
                reference: entry.$2,
                controller: controller,
              ),
            ),
          ],
          const Divider(height: 28),
          _sectionHeader(
            title: '多角色与坐标',
            icon: Icons.group_add_outlined,
            label: '添加角色',
            onPressed: controller.characterPrompts.length >= 6
                ? null
                : controller.addCharacter,
          ),
          ...controller.characterPrompts.indexed.map(
            (entry) => _CharacterTile(
              index: entry.$1,
              character: entry.$2,
              controller: controller,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required String title,
    required IconData icon,
    required VoidCallback? onPressed,
    String label = '添加',
  }) => Row(
    children: [
      Expanded(child: Text(title)),
      TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    ],
  );
}

class _VibeTile extends StatelessWidget {
  const _VibeTile({
    required this.index,
    required this.reference,
    required this.controller,
    required this.onEncode,
    required this.onExport,
  });

  final int index;
  final VibeReference reference;
  final GenerationController controller;
  final VoidCallback onEncode;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final hasEncoding = reference.hasEncoding;
    final canEncode = reference.hasReencodeSource && !hasEncoding;
    final displayName = reference.displayName ?? 'Vibe ${index + 1}';
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: delete · name · Anlas badge · enable toggle
          Row(
            children: [
              IconButton(
                onPressed: () => controller.removeVibeReference(index),
                icon: const Icon(Icons.delete_outline, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: '移除',
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  displayName,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Download the encoded vibe for reuse elsewhere.
              if (hasEncoding)
                IconButton(
                  onPressed: onExport,
                  icon: const Icon(Icons.download_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  tooltip: '下载 Vibe 文件',
                ),
              const SizedBox(width: 4),
              // Anlas cost chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: hasEncoding
                      ? colors.primaryContainer.withValues(alpha: 0.5)
                      : colors.tertiaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasEncoding ? '0' : '2',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: hasEncoding
                            ? colors.onPrimaryContainer
                            : colors.onTertiaryContainer,
                      ),
                    ),
                    const SizedBox(width: 2),
                    AnlasIcon(
                      size: 12,
                      color: hasEncoding
                          ? colors.onPrimaryContainer
                          : colors.onTertiaryContainer,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: reference.enabled,
                onChanged: hasEncoding || reference.enabled
                    ? (value) => controller.updateVibeReference(
                        index,
                        reference.copyWith(enabled: value),
                      )
                    : null,
              ),
            ],
          ),

          // Wide preview image
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildWidePreview(context, hasEncoding),
            ),
          ),

          // Reference Strength
          const SizedBox(height: 8),
          _labeledSlider(
            context: context,
            label: '参考强度',
            value: reference.strength,
            onChanged: (value) => controller.updateVibeReference(
              index,
              reference.copyWith(strength: value),
            ),
          ),

          // Information Extracted — cached per value, so switching back to a
          // previously encoded value costs nothing.
          _labeledSlider(
            context: context,
            label: '信息提取',
            value: reference.informationExtracted,
            onChanged: (value) =>
                controller.updateVibeInformationExtracted(index, value),
          ),

          // Encode button + status
          const SizedBox(height: 4),
          if (canEncode)
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: onEncode,
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: Text(
                  reference.encodingCache.isEmpty
                      ? '编码此 Vibe (2 Anlas)'
                      : '编码当前提取值 (2 Anlas)',
                ),
              ),
            )
          else
            Row(
              children: [
                Icon(
                  hasEncoding
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  size: 14,
                  color: hasEncoding ? colors.primary : colors.tertiary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hasEncoding ? '已编码，可直接启用参与生成。' : '文件不含原始参考图，无法按当前提取值重新编码。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),

          const Divider(height: 20),
        ],
      ),
    );
  }

  Widget _buildWidePreview(BuildContext context, bool hasEncoding) {
    const height = 120.0;
    // Priority 1: local image file
    if (reference.imagePath != null && reference.imagePath!.isNotEmpty) {
      return Image.file(
        File(reference.imagePath!),
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
    // Priority 2: base64 thumbnail from vibe file
    if (reference.thumbnailBase64 != null &&
        reference.thumbnailBase64!.isNotEmpty) {
      return Image.memory(
        base64Decode(reference.thumbnailBase64!),
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
    // Priority 3: placeholder
    return Container(
      width: double.infinity,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        hasEncoding ? Icons.verified_rounded : Icons.blur_on_rounded,
        size: 36,
        color: hasEncoding
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _labeledSlider({
    required BuildContext context,
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 160,
          child: Text(
            '$label  ${value.toStringAsFixed(2)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value,
              min: 0.01,
              max: 1,
              divisions: 99,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _CharacterReferenceTile extends StatelessWidget {
  const _CharacterReferenceTile({
    required this.index,
    required this.reference,
    required this.controller,
  });

  final int index;
  final CharacterReference reference;
  final GenerationController controller;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    leading: ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.file(
        File(reference.imagePath),
        width: 44,
        height: 44,
        fit: BoxFit.cover,
      ),
    ),
    title: Text('角色参考 ${index + 1} · +5A'),
    subtitle: Text(reference.description),
    trailing: IconButton(
      onPressed: () => controller.removeCharacterReference(index),
      icon: const Icon(Icons.delete_outline),
    ),
    children: [
      DropdownButtonFormField<CharacterReferenceType>(
        initialValue: reference.type,
        decoration: const InputDecoration(labelText: '参考类型'),
        items: const [
          DropdownMenuItem(
            value: CharacterReferenceType.characterAndStyle,
            child: Text('角色与画风'),
          ),
          DropdownMenuItem(
            value: CharacterReferenceType.character,
            child: Text('仅角色'),
          ),
          DropdownMenuItem(
            value: CharacterReferenceType.style,
            child: Text('仅画风'),
          ),
        ],
        onChanged: (value) => controller.updateCharacterReference(
          index,
          reference.copyWith(type: value),
        ),
      ),
      Text('强度 ${reference.strength.toStringAsFixed(2)}'),
      Slider(
        value: reference.strength,
        min: 0,
        max: 1,
        divisions: 20,
        onChanged: (value) => controller.updateCharacterReference(
          index,
          reference.copyWith(strength: value),
        ),
      ),
      Text('忠诚度 ${reference.fidelity.toStringAsFixed(2)}'),
      Slider(
        value: reference.fidelity,
        min: 0,
        max: 1,
        divisions: 20,
        onChanged: (value) => controller.updateCharacterReference(
          index,
          reference.copyWith(fidelity: value),
        ),
      ),
    ],
  );
}

class _CharacterTile extends StatelessWidget {
  const _CharacterTile({
    required this.index,
    required this.character,
    required this.controller,
  });

  final int index;
  final CharacterPrompt character;
  final GenerationController controller;

  @override
  Widget build(BuildContext context) => Card.outlined(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('角色 ${index + 1}')),
              Switch.adaptive(
                value: character.enabled,
                onChanged: (value) => controller.updateCharacter(
                  index,
                  character.copyWith(enabled: value),
                ),
              ),
              IconButton(
                onPressed: () => controller.removeCharacter(index),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          TextFormField(
            initialValue: character.prompt,
            onChanged: (value) => controller.updateCharacter(
              index,
              character.copyWith(prompt: value),
            ),
            decoration: const InputDecoration(labelText: '角色正向提示词'),
          ),
          TextFormField(
            initialValue: character.negativePrompt,
            onChanged: (value) => controller.updateCharacter(
              index,
              character.copyWith(negativePrompt: value),
            ),
            decoration: const InputDecoration(labelText: '角色负向提示词'),
          ),
          const SizedBox(height: 12),
          CharacterPositionGrid(
            value: character.position,
            canvasWidth: controller.width,
            canvasHeight: controller.height,
            onChanged: (position) => controller.updateCharacter(
              index,
              character.copyWith(position: position),
            ),
          ),
        ],
      ),
    ),
  );
}
