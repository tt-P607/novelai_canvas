import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/advanced_generation.dart';
import '../../domain/entities/generation_task.dart';
import '../controllers/generation_controller.dart';
import '../controllers/llm_assistant_settings_controller.dart';
import '../controllers/prompt_assistant_controller.dart';
import 'mask_editor_page.dart';
import 'prompt_assistant_page.dart';

class CreationPage extends StatefulWidget {
  const CreationPage({
    super.key,
    required this.controller,
    required this.promptAssistantController,
    required this.llmSettingsController,
  });

  final GenerationController controller;
  final PromptAssistantController promptAssistantController;
  final LlmAssistantSettingsController llmSettingsController;

  @override
  State<CreationPage> createState() => _CreationPageState();
}

class _CreationPageState extends State<CreationPage> {
  late final TextEditingController _promptController;
  late final TextEditingController _negativeController;
  late final TextEditingController _modelController;
  late final TextEditingController _seedController;
  final ImagePicker _picker = ImagePicker();

  GenerationController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(text: controller.prompt);
    _negativeController = TextEditingController(
      text: controller.negativePrompt,
    );
    _modelController = TextEditingController(text: controller.model);
    _seedController = TextEditingController(text: controller.seed.toString());
    controller.addListener(_syncControllers);
  }

  void _syncControllers() {
    if (_promptController.text != controller.prompt) {
      _promptController.text = controller.prompt;
    }
    if (_negativeController.text != controller.negativePrompt) {
      _negativeController.text = controller.negativePrompt;
    }
    if (_modelController.text != controller.model) {
      _modelController.text = controller.model;
    }
    final seed = controller.seed.toString();
    if (_seedController.text != seed) _seedController.text = seed;
  }

  @override
  void dispose() {
    controller.removeListener(_syncControllers);
    _promptController.dispose();
    _negativeController.dispose();
    _modelController.dispose();
    _seedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: const Text('创作'),
              actions: [
                IconButton(
                  tooltip: '提示词助手',
                  onPressed: _openPromptAssistant,
                  icon: const Icon(Icons.auto_fix_high_rounded),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Chip(
                    avatar: Icon(
                      controller.queueState.isRunning
                          ? Icons.hourglass_top_rounded
                          : Icons.cloud_done_rounded,
                      size: 18,
                    ),
                    label: Text(
                      controller.queueState.isRunning
                          ? '生成中 · ${controller.queueState.pendingCount} 排队'
                          : '${controller.queueState.pendingCount} 个任务排队',
                    ),
                  ),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList.list(
                children: [
                  _modeSelector(),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _promptController,
                    minLines: 4,
                    maxLines: 8,
                    onChanged: controller.updatePrompt,
                    decoration: const InputDecoration(
                      labelText: '正向提示词',
                      hintText: '1girl, masterpiece, cinematic lighting...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _negativeController,
                    minLines: 2,
                    maxLines: 5,
                    onChanged: controller.updateNegativePrompt,
                    decoration: const InputDecoration(
                      labelText: '负向提示词',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _parameterCard(),
                  if (controller.mode == GenerationMode.textToImage) ...[
                    const SizedBox(height: 16),
                    _advancedReferenceCard(),
                  ],
                  if (controller.mode != GenerationMode.textToImage) ...[
                    const SizedBox(height: 16),
                    _imageInputCard(),
                  ],
                  const SizedBox(height: 16),
                  _statusCard(),
                  if (controller.queueState.previewImageBytes != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Image.memory(
                            Uint8List.fromList(
                              controller.queueState.previewImageBytes!,
                            ),
                            width: double.infinity,
                            fit: BoxFit.contain,
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              '原生流式预览 · Step ${controller.queueState.previewStep ?? 0}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: controller.queueState.isRunning ? null : _submit,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('加入生成队列'),
                    ),
                  ),
                  if (controller.queueState.isRunning) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: controller.cancelActive,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('取消当前任务'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeSelector() => SegmentedButton<GenerationMode>(
    segments: const [
      ButtonSegment(
        value: GenerationMode.textToImage,
        icon: Icon(Icons.text_fields_rounded),
        label: Text('文生图'),
      ),
      ButtonSegment(
        value: GenerationMode.imageToImage,
        icon: Icon(Icons.image_rounded),
        label: Text('图生图'),
      ),
      ButtonSegment(
        value: GenerationMode.inpaint,
        icon: Icon(Icons.brush_rounded),
        label: Text('局部重绘'),
      ),
    ],
    selected: {controller.mode},
    onSelectionChanged: (selection) => controller.updateMode(selection.single),
  );

  Widget _parameterCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('生成参数', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _modelController,
            onChanged: controller.updateModel,
            decoration: const InputDecoration(
              labelText: '模型',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: '${controller.width}x${controller.height}',
            decoration: const InputDecoration(
              labelText: '尺寸',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: '832x1216', child: Text('竖图 832 × 1216')),
              DropdownMenuItem(value: '1216x832', child: Text('横图 1216 × 832')),
              DropdownMenuItem(
                value: '1024x1024',
                child: Text('方图 1024 × 1024'),
              ),
            ],
            onChanged: (value) {
              final parts = value!.split('x');
              controller.updateSize(
                width: int.parse(parts[0]),
                height: int.parse(parts[1]),
              );
            },
          ),
          const SizedBox(height: 16),
          Text('步数 ${controller.steps}'),
          Slider(
            value: controller.steps.toDouble(),
            min: 1,
            max: 50,
            divisions: 49,
            onChanged: controller.updateSteps,
          ),
          Text('提示词相关性 ${controller.scale.toStringAsFixed(1)}'),
          Slider(
            value: controller.scale,
            min: 1,
            max: 10,
            divisions: 18,
            onChanged: controller.updateScale,
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _seedController,
                  keyboardType: TextInputType.number,
                  onChanged: controller.updateSeed,
                  decoration: const InputDecoration(
                    labelText: 'Seed（0 为随机）',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                tooltip: '随机 Seed',
                onPressed: controller.randomizeSeed,
                icon: const Icon(Icons.casino_rounded),
              ),
            ],
          ),
          if (controller.mode != GenerationMode.textToImage) ...[
            const SizedBox(height: 12),
            Text('重绘强度 ${controller.strength.toStringAsFixed(2)}'),
            Slider(
              value: controller.strength,
              min: 0,
              max: 1,
              divisions: 20,
              onChanged: controller.updateStrength,
            ),
            Text('噪声 ${controller.noise.toStringAsFixed(2)}'),
            Slider(
              value: controller.noise,
              min: 0,
              max: 1,
              divisions: 20,
              onChanged: controller.updateNoise,
            ),
          ],
          if (controller.mode == GenerationMode.textToImage)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('原生 SSE 中间预览'),
              subtitle: const Text('仅 NovelAI 原生后端可用'),
              value: controller.stream,
              onChanged: controller.updateStream,
            ),
        ],
      ),
    ),
  );

  Widget _advancedReferenceCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('高级参考', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('Vibe 控制风格；角色参考仅支持原生 V4.5；多角色最多 6 个。'),
          const Divider(height: 28),
          Row(
            children: [
              const Expanded(child: Text('Vibe Transfer')),
              TextButton.icon(
                onPressed: _pickVibeImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('添加'),
              ),
            ],
          ),
          ...controller.vibeReferences.indexed.map(
            (entry) => _vibeTile(entry.$1, entry.$2),
          ),
          const Divider(height: 28),
          Row(
            children: [
              const Expanded(child: Text('V4.5 角色参考')),
              TextButton.icon(
                onPressed: _pickCharacterReference,
                icon: const Icon(Icons.person_add_alt_rounded),
                label: const Text('添加'),
              ),
            ],
          ),
          ...controller.characterReferences.indexed.map(
            (entry) => _characterReferenceTile(entry.$1, entry.$2),
          ),
          const Divider(height: 28),
          Row(
            children: [
              const Expanded(child: Text('多角色与坐标')),
              TextButton.icon(
                onPressed: controller.characterPrompts.length >= 6
                    ? null
                    : controller.addCharacter,
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('添加角色'),
              ),
            ],
          ),
          ...controller.characterPrompts.indexed.map(
            (entry) => _characterTile(entry.$1, entry.$2),
          ),
        ],
      ),
    ),
  );

  Widget _vibeTile(int index, VibeReference reference) => ExpansionTile(
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
      '强度 ${reference.strength.toStringAsFixed(2)} · 提取 ${reference.informationExtracted.toStringAsFixed(2)}',
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

  Widget _characterReferenceTile(int index, CharacterReference reference) =>
      ExpansionTile(
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

  Widget _characterTile(int index, CharacterPrompt character) => Card.outlined(
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
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _positionKey(character.position),
            decoration: const InputDecoration(labelText: '5 × 5 角色点位'),
            items: _characterPositions()
                .map(
                  (entry) =>
                      DropdownMenuItem(value: entry.$1, child: Text(entry.$1)),
                )
                .toList(),
            onChanged: (key) {
              final position = _characterPositions()
                  .firstWhere((entry) => entry.$1 == key)
                  .$2;
              controller.updateCharacter(
                index,
                character.copyWith(position: position),
              );
            },
          ),
        ],
      ),
    ),
  );

  Future<void> _pickVibeImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) controller.addVibeReference(image.path);
  }

  Future<void> _pickCharacterReference() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) controller.addCharacterReference(image.path);
  }

  List<(String, CharacterPosition)> _characterPositions() => [
    for (var row = 0; row < 5; row++)
      for (var column = 0; column < 5; column++)
        (
          '${String.fromCharCode(65 + row)}${column + 1}',
          CharacterPosition(x: 0.1 + column * 0.2, y: 0.1 + row * 0.2),
        ),
  ];

  String _positionKey(CharacterPosition position) {
    final column = ((position.x - 0.1) / 0.2).round().clamp(0, 4);
    final row = ((position.y - 0.1) / 0.2).round().clamp(0, 4);
    return '${String.fromCharCode(65 + row)}${column + 1}';
  }

  Widget _imageInputCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('图片输入', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (controller.sourceImagePath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(controller.sourceImagePath!),
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _pickImage(mask: false),
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(controller.sourceImagePath == null ? '选择源图片' : '更换源图片'),
          ),
          if (controller.mode == GenerationMode.inpaint) ...[
            const Divider(height: 28),
            Text(controller.maskImagePath == null ? '尚未选择蒙版' : '已选择蒙版文件'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _pickImage(mask: true),
              icon: const Icon(Icons.layers_outlined),
              label: const Text('选择蒙版 PNG'),
            ),
            FilledButton.tonalIcon(
              onPressed: controller.sourceImagePath == null
                  ? null
                  : _openMaskEditor,
              icon: const Icon(Icons.brush_rounded),
              label: const Text('打开蒙版画板'),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _statusCard() {
    final task = controller.latestTask;
    if (task == null) return const SizedBox.shrink();
    final color = switch (task.status) {
      GenerationTaskStatus.completed => Colors.green,
      GenerationTaskStatus.failed => Colors.red,
      GenerationTaskStatus.cancelled => Colors.orange,
      _ => Theme.of(context).colorScheme.primary,
    };
    return Card(
      child: ListTile(
        leading: Icon(Icons.bubble_chart_rounded, color: color),
        title: Text(_statusLabel(task.status)),
        subtitle: Text(task.errorMessage ?? task.spec.prompt),
        trailing: task.status == GenerationTaskStatus.running
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
      ),
    );
  }

  Future<void> _pickImage({required bool mask}) async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    if (mask) {
      controller.setMaskImage(image.path);
    } else {
      controller.setSourceImage(image.path);
    }
  }

  Future<void> _openMaskEditor() async {
    final sourcePath = controller.sourceImagePath;
    if (sourcePath == null) return;
    final maskPath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => MaskEditorPage(
          sourceImagePath: sourcePath,
          outputWidth: controller.width,
          outputHeight: controller.height,
        ),
      ),
    );
    if (maskPath != null) controller.setMaskImage(maskPath);
  }

  Future<void> _openPromptAssistant() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => PromptAssistantPage(
          controller: widget.promptAssistantController,
          settingsController: widget.llmSettingsController,
          generationController: controller,
        ),
      ),
    );
  }

  Future<void> _submit() async {
    try {
      await controller.submit();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('任务已加入持久化生成队列。')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  String _statusLabel(GenerationTaskStatus status) => switch (status) {
    GenerationTaskStatus.draft => '草稿',
    GenerationTaskStatus.queued => '等待生成',
    GenerationTaskStatus.running => '正在生成',
    GenerationTaskStatus.completed => '生成完成',
    GenerationTaskStatus.failed => '生成失败',
    GenerationTaskStatus.cancelled => '已取消',
    GenerationTaskStatus.interrupted => '生成中断',
  };
}
