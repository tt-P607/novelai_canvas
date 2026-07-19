import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/advanced_generation.dart';
import '../../domain/entities/generation_task.dart';
import '../controllers/generation_controller.dart';
import '../controllers/llm_assistant_settings_controller.dart';
import '../controllers/prompt_assistant_controller.dart';
import '../widgets/character_position_grid.dart';
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
  late final TextEditingController _customWidthController;
  late final TextEditingController _customHeightController;
  final ImagePicker _picker = ImagePicker();
  bool _assistantMinimized = false;

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
    _customWidthController = TextEditingController(
      text: controller.width.toString(),
    );
    _customHeightController = TextEditingController(
      text: controller.height.toString(),
    );
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
    final width = controller.width.toString();
    final height = controller.height.toString();
    if (_customWidthController.text != width) {
      _customWidthController.text = width;
    }
    if (_customHeightController.text != height) {
      _customHeightController.text = height;
    }
  }

  @override
  void dispose() {
    controller.removeListener(_syncControllers);
    _promptController.dispose();
    _negativeController.dispose();
    _modelController.dispose();
    _seedController.dispose();
    _customWidthController.dispose();
    _customHeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          ListenableBuilder(
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
                      _resultPanel(),
                      const SizedBox(height: 14),
                      _primaryActions(),
                      const SizedBox(height: 18),
                      _modeSelector(),
                      const SizedBox(height: 14),
                      _assistantShortcut(),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _promptController,
                        minLines: 3,
                        maxLines: 7,
                        onChanged: controller.updatePrompt,
                        decoration: const InputDecoration(
                          labelText: '正向提示词',
                          hintText: '1girl, masterpiece, cinematic lighting...',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _negativeController,
                        minLines: 2,
                        maxLines: 4,
                        onChanged: controller.updateNegativePrompt,
                        decoration: const InputDecoration(
                          labelText: '负向提示词',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (controller.mode != GenerationMode.textToImage) ...[
                        const SizedBox(height: 18),
                        _imageInputCard(),
                      ],
                      const SizedBox(height: 18),
                      _parameterCard(),
                      if (controller.mode == GenerationMode.textToImage) ...[
                        const SizedBox(height: 18),
                        _advancedReferenceCard(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_assistantMinimized)
            Positioned(
              right: 18,
              bottom: 92,
              child: FloatingActionButton.small(
                heroTag: 'prompt-assistant-bubble',
                tooltip: '打开提示词助手',
                onPressed: () {
                  setState(() => _assistantMinimized = false);
                  _openPromptAssistant();
                },
                child: const Icon(Icons.auto_fix_high_rounded),
              ),
            ),
        ],
      ),
    );
  }

  Widget _resultPanel() {
    final previewBytes = controller.queueState.previewImageBytes;
    final completedPath = controller.latestImagePath;
    final hasPreview = previewBytes != null;
    final hasCompleted =
        completedPath != null && File(completedPath).existsSync();
    if (!hasPreview && !hasCompleted) {
      return Container(
        height: 156,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_outlined, size: 34),
              SizedBox(height: 8),
              Text('生成结果会显示在这里'),
            ],
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RepaintBoundary(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.center,
                children: [...previousChildren, ?currentChild],
              ),
              child: hasPreview
                  ? Image.memory(
                      Uint8List.fromList(previewBytes),
                      key: const ValueKey('stream-preview'),
                      width: double.infinity,
                      height: 280,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.low,
                    )
                  : Image.file(
                      File(completedPath!),
                      key: ValueKey(completedPath),
                      width: double.infinity,
                      height: 280,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  hasPreview
                      ? Icons.motion_photos_on_outlined
                      : Icons.check_circle_outline_rounded,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasPreview
                        ? '渐进式预览 · Step ${controller.queueState.previewStep ?? 0}'
                        : '最新生成结果',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryActions() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton.icon(
        onPressed: controller.queueState.isRunning ? null : _submit,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: Text(controller.queueState.isRunning ? '正在生成…' : '立即生成'),
      ),
      if (controller.latestTask != null) ...[
        const SizedBox(height: 8),
        _statusCard(),
      ],
      if (controller.queueState.isRunning) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: controller.cancelActive,
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('取消当前任务'),
        ),
      ],
    ],
  );

  Widget _assistantShortcut() {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.secondaryContainer.withValues(alpha: 0.32),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _openPromptAssistant,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.auto_fix_high_rounded, color: colors.secondary),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '自然语言写提示词',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 2),
                    Text('点击即用：描述画面，整理后直接回填下方输入框'),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded),
            ],
          ),
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
            initialValue: _officialSizeValue(),
            decoration: const InputDecoration(labelText: '官方画幅预设'),
            items: const [
              DropdownMenuItem(
                value: '832x1216',
                child: Text('竖图 · 832 × 1216'),
              ),
              DropdownMenuItem(
                value: '1024x1024',
                child: Text('方图 · 1024 × 1024'),
              ),
              DropdownMenuItem(
                value: '1216x832',
                child: Text('横图 · 1216 × 832'),
              ),
              DropdownMenuItem(
                value: '1024x1536',
                child: Text('大竖图 · 1024 × 1536 · 消耗 Anlas'),
              ),
              DropdownMenuItem(
                value: '1536x1024',
                child: Text('大横图 · 1536 × 1024 · 消耗 Anlas'),
              ),
              DropdownMenuItem(value: 'custom', child: Text('自定义画幅')),
            ],
            onChanged: (value) {
              if (value == null || value == 'custom') return;
              final parts = value.split('x');
              controller.updateSize(
                width: int.parse(parts[0]),
                height: int.parse(parts[1]),
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customWidthController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '自定义宽度'),
                  onSubmitted: (_) => _applyCustomSize(),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('×'),
              ),
              Expanded(
                child: TextField(
                  controller: _customHeightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '自定义高度'),
                  onSubmitted: (_) => _applyCustomSize(),
                ),
              ),
              IconButton.filledTonal(
                tooltip: '应用自定义画幅',
                onPressed: _applyCustomSize,
                icon: const Icon(Icons.check_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '范围 64–1600，保存时自动对齐到最接近的 64 倍数。',
            style: Theme.of(context).textTheme.bodySmall,
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
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('渐进式中间预览'),
            subtitle: const Text('NovelAI 原生后端的文生图、图生图和局部重绘均可使用'),
            value: controller.stream,
            onChanged: controller.updateStream,
          ),
          if (controller.mode == GenerationMode.inpaint)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('边缘融合'),
              subtitle: const Text('默认开启，将原图叠加到结果边缘以减少局部重绘割裂'),
              value: controller.addOriginalImage,
              onChanged: controller.updateAddOriginalImage,
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
          const SizedBox(height: 12),
          CharacterPositionGrid(
            value: character.position,
            onChanged: (position) => controller.updateCharacter(
              index,
              character.copyWith(position: position),
            ),
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
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width >= 720
            ? 520
            : double.infinity,
      ),
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.88,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '提示词助手',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '缩小为悬浮球',
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      setState(() => _assistantMinimized = true);
                    },
                    icon: const Icon(Icons.minimize_rounded),
                  ),
                  IconButton(
                    tooltip: '全屏打开',
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (context) => PromptAssistantPage(
                            controller: widget.promptAssistantController,
                            settingsController: widget.llmSettingsController,
                            generationController: controller,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.open_in_full_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PromptAssistantPage(
                controller: widget.promptAssistantController,
                settingsController: widget.llmSettingsController,
                generationController: controller,
                embedded: true,
                onApplied: () => Navigator.pop(sheetContext),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _officialSizeValue() {
    final value = '${controller.width}x${controller.height}';
    return const {
          '832x1216',
          '1024x1024',
          '1216x832',
          '1024x1536',
          '1536x1024',
        }.contains(value)
        ? value
        : 'custom';
  }

  void _applyCustomSize() {
    controller.updateCustomSize(
      width: _customWidthController.text,
      height: _customHeightController.text,
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
