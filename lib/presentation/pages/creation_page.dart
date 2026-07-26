import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/errors/error_message.dart';
import '../../domain/entities/generation_task.dart';
import '../controllers/generation_controller.dart';
import '../controllers/llm_assistant_settings_controller.dart';
import '../controllers/prompt_assistant_controller.dart';
import '../widgets/advanced_reference_card.dart';
import '../widgets/compact_snack_bar.dart';
import '../widgets/draggable_assistant_bubble.dart';
import '../widgets/generation_parameter_card.dart';
import '../widgets/generation_result_panel.dart';
import '../widgets/glass/liquid_glass.dart';
import 'mask_editor_page.dart';
import 'prompt_assistant_page.dart';

class CreationPage extends StatefulWidget {
  const CreationPage({
    super.key,
    required this.controller,
    required this.promptAssistantController,
    required this.llmSettingsController,
    this.onOpenImageTools,
  });

  final GenerationController controller;
  final PromptAssistantController promptAssistantController;
  final LlmAssistantSettingsController llmSettingsController;
  final ValueChanged<String>? onOpenImageTools;

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
    controller.refreshSubscription();
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

  /// Mirrors controller state back into the text fields after the assistant or
  /// a history reuse changed values programmatically.
  void _syncControllers() {
    _syncField(_promptController, controller.prompt);
    _syncField(_negativeController, controller.negativePrompt);
    _syncField(_modelController, controller.model);
    _syncField(_seedController, controller.seed.toString());
    _syncField(_customWidthController, controller.width.toString());
    _syncField(_customHeightController, controller.height.toString());
  }

  void _syncField(TextEditingController field, String value) {
    if (field.text != value) field.text = value;
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
                      child: _queueChip(),
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverList.list(children: _sections()),
                ),
              ],
            ),
          ),
          if (_assistantMinimized)
            DraggableAssistantBubble(
              onPressed: () {
                setState(() => _assistantMinimized = false);
                _openPromptAssistant();
              },
            ),
        ],
      ),
    );
  }

  List<Widget> _sections() => [
    GenerationResultPanel(
      previewBytes: controller.queueState.previewImageBytes,
      previewStep: controller.queueState.previewStep,
      totalSteps: controller.queueState.activeTask?.spec.steps ?? 0,
      completedImagePath: controller.latestImagePath,
      onSendToImageTools: widget.onOpenImageTools,
    ),
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
    GenerationParameterCard(
      controller: controller,
      modelController: _modelController,
      seedController: _seedController,
      widthController: _customWidthController,
      heightController: _customHeightController,
    ),
    if (controller.mode == GenerationMode.textToImage) ...[
      const SizedBox(height: 18),
      AdvancedReferenceCard(
        controller: controller,
        onAddVibe: _pickVibeImage,
        onAddCharacterReference: _pickCharacterReference,
      ),
    ],
  ];

  Widget _queueChip() {
    final isRunning = controller.queueState.isRunning;
    final pending = controller.queueState.pendingCount;
    return Chip(
      avatar: Icon(
        isRunning ? Icons.hourglass_top_rounded : Icons.cloud_done_rounded,
        size: 18,
      ),
      label: Text(isRunning ? '生成中 · $pending 排队' : '$pending 个任务排队'),
    );
  }

  /// Mirrors the official cost preview: free generations show a check, billable
  /// ones show the estimated Anlas so there is no surprise after tapping.
  Widget _anlasBadge() {
    final estimate = controller.anlasEstimate;
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.onPrimary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estimate.isFree ? '免费' : '${estimate.total} Anlas',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _primaryActions() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton.icon(
        onPressed: controller.queueState.isRunning ? null : _submit,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(controller.queueState.isRunning ? '正在生成…' : '立即生成'),
            const SizedBox(width: 8),
            _anlasBadge(),
          ],
        ),
      ),
      if (controller.latestTask != null) ...[
        const SizedBox(height: 8),
        _statusCard(controller.latestTask!),
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

  Widget _statusCard(GenerationTask task) {
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

  Widget _assistantShortcut() {
    final colors = Theme.of(context).colorScheme;
    return LiquidGlass(
      radius: 18,
      tintOpacity: 0.10,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: _openPromptAssistant,
      child: Row(
        children: [
          Icon(Icons.auto_fix_high_rounded, color: colors.secondary),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('自然语言写提示词', style: TextStyle(fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('点击即用：描述画面，整理后直接回填下方输入框'),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded),
        ],
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
            onPressed: _pickSourceImage,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(controller.sourceImagePath == null ? '选择源图片' : '更换源图片'),
          ),
          if (controller.mode == GenerationMode.inpaint) ...[
            const Divider(height: 28),
            FilledButton.tonalIcon(
              onPressed: controller.sourceImagePath == null
                  ? null
                  : _openMaskEditor,
              icon: const Icon(Icons.brush_rounded),
              label: Text(
                controller.maskImagePath == null ? '涂抹重绘区域' : '重新编辑重绘区域',
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Future<void> _pickSourceImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) controller.setSourceImage(image.path);
  }

  Future<void> _pickVibeImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) controller.addVibeReference(image.path);
  }

  Future<void> _pickCharacterReference() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) controller.addCharacterReference(image.path);
  }

  Future<void> _openMaskEditor() async {
    final sourcePath = controller.sourceImagePath;
    if (sourcePath == null) return;
    final maskPath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => MaskEditorPage(sourceImagePath: sourcePath),
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

  Future<void> _submit() async {
    try {
      final task = await controller.submit();
      if (!mounted) return;
      showCompactSnackBar(
        context,
        icon: Icons.schedule_rounded,
        message: task.status == GenerationTaskStatus.running
            ? '已开始生成'
            : '已加入生成队列',
      );
    } catch (error) {
      if (!mounted) return;
      showCompactSnackBar(
        context,
        icon: Icons.error_outline_rounded,
        message: friendlyErrorMessage(error),
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
