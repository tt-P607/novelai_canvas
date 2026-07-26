import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/entities/advanced_generation.dart';
import '../controllers/generation_controller.dart';
import 'character_position_grid.dart';
import 'glass/liquid_glass.dart';

/// Vibe transfer, V4.5 character references and multi-character coordinates.
class AdvancedReferenceCard extends StatelessWidget {
  const AdvancedReferenceCard({
    super.key,
    required this.controller,
    required this.onAddVibe,
    required this.onAddCharacterReference,
  });

  final GenerationController controller;
  final VoidCallback onAddVibe;
  final VoidCallback onAddCharacterReference;

  @override
  Widget build(BuildContext context) => LiquidGlass(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('高级参考', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text('Vibe 控制风格；角色参考仅支持原生 V4.5；多角色最多 6 个。'),
        const Divider(height: 28),
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
          ),
        ),
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
  });

  final int index;
  final VibeReference reference;
  final GenerationController controller;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    leading: reference.imagePath == null
        ? const Icon(Icons.blur_on_rounded)
        : ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              File(reference.imagePath!),
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
    title: Text('Vibe ${index + 1}'),
    subtitle: Text(
      '强度 ${reference.strength.toStringAsFixed(2)} · '
      '提取 ${reference.informationExtracted.toStringAsFixed(2)}',
    ),
    trailing: IconButton(
      onPressed: () => controller.removeVibeReference(index),
      icon: const Icon(Icons.delete_outline),
    ),
    children: [
      Text('参考强度 ${reference.strength.toStringAsFixed(2)}'),
      Slider(
        value: reference.strength,
        min: 0.01,
        max: 1,
        divisions: 99,
        onChanged: (value) => controller.updateVibeReference(
          index,
          reference.copyWith(strength: value),
        ),
      ),
      Text('信息提取 ${reference.informationExtracted.toStringAsFixed(2)}'),
      Slider(
        value: reference.informationExtracted,
        min: 0.01,
        max: 1,
        divisions: 99,
        onChanged: (value) => controller.updateVibeReference(
          index,
          reference.copyWith(informationExtracted: value),
        ),
      ),
    ],
  );
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
