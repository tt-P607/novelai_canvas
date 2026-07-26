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
import '../widgets/floating_assistant_window.dart';
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
  _AssistantMode _assistantMode = _AssistantMode.hidden;

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
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('创作'),
                      const SizedBox(width: 10),
                      _tierBadge(),
                    ],
                  ),
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
          if (_assistantMode == _AssistantMode.window)
            FloatingAssistantWindow(
              onMinimize: () =>
                  setState(() => _assistantMode = _AssistantMode.bubble),
              onExpand: () {
                setState(() => _assistantMode = _AssistantMode.hidden);
                _openPromptAssistant();
              },
              child: PromptAssistantPage(
                controller: widget.promptAssistantController,
                settingsController: widget.llmSettingsController,
                generationController: controller,
                embedded: true,
              ),
            ),
          if (_assistantMode == _AssistantMode.bubble)
            DraggableAssistantBubble(
              onPressed: () =>
                  setState(() => _assistantMode = _AssistantMode.window),
            ),
        ],
      ),
    );
  }

  /// Section order follows the task flow: pick the mode first, feed it inputs
  /// (source image and mask sit directly below the mode switch so inpainting
  /// never requires scrolling), then prompts, then advanced parameters.
  List<Widget> _sections() => [
    _modeSelector(),
    const SizedBox(height: 14),
    GenerationResultPanel(
      previewBytes: controller.queueState.previewImageBytes,
      previewStep: controller.queueState.previewStep,
      totalSteps: controller.queueState.activeTask?.spec.steps ?? 0,
      completedImagePath: controller.latestImagePath,
      onSendToImageTools: widget.onOpenImageTools,
      onInpaint: _inpaintLatest,
    ),
    if (controller.mode != GenerationMode.textToImage) ...[
      const SizedBox(height: 14),
      _imageInputCard(),
    ],
    const SizedBox(height: 14),
    _primaryActions(),
    const SizedBox(height: 18),
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

  /// Compact tier chip next to the page title. Tapping it re-checks the
  /// subscription immediately.
  Widget _tierBadge() {
    final colors = Theme.of(context).colorScheme;
    final name = controller.subscriptionTierName;
    final label = controller.subscriptionLoading && name == null
        ? '…'
        : (name ?? '未知等级');
    final highlight = controller.isOpus;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => controller.refreshSubscription(force: true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: highlight
              ? colors.primaryContainer
              : colors.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              highlight
                  ? Icons.workspace_premium_rounded
                  : Icons.person_outline_rounded,
              size: 14,
              color: highlight ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: highlight
                    ? colors.onPrimaryContainer
                    : colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  /// Mirrors the official cost preview: free generations show 免费, billable
  /// ones show the estimated Anlas so there is no surprise after tapping.
  ///
  /// While the subscription tier is unknown the number would be wrong for Opus
  /// accounts, so it is withheld rather than shown as a definite cost.
  Widget _anlasBadge() {
    final colors = Theme.of(context).colorScheme;
    final label = switch (controller) {
      final c when c.subscriptionLoading => '…',
      final c when !c.subscriptionKnown => '?',
      final c when c.anlasEstimate.isFree => '免费',
      final c => '${c.anlasEstimate.total} Anlas',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.onPrimary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Explains why the cost preview is provisional and offers a retry, since the
  /// tier lookup fails whenever the token is missing or the network is down.
  Widget _subscriptionNotice() {
    if (controller.subscriptionKnown || controller.subscriptionLoading) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: colors.tertiary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              controller.subscriptionError == null
                  ? '尚未读取账户等级，消耗预览暂不可用。'
                  : '账户等级读取失败：${controller.subscriptionError}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.tertiary),
            ),
          ),
          TextButton(
            onPressed: () => controller.refreshSubscription(force: true),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  /// Number of tasks queued per tap, dragged freely on a slider (1-15). The
  /// queue executes strictly serially, so this is continuous auto-generation
  /// rather than parallelism.
  Widget _batchSelector() {
    return Row(
      children: [
        Icon(
          Icons.repeat_rounded,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text('连续生成', style: Theme.of(context).textTheme.bodySmall),
        Expanded(
          child: Slider(
            value: controller.batchCount.toDouble(),
            min: 1,
            max: 15,
            divisions: 14,
            label: '${controller.batchCount} 张',
            onChanged: (value) => controller.updateBatchCount(value.round()),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '${controller.batchCount} 张',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  /// Pause between queued tasks, user-configurable down to 0.3 s.
  Widget _intervalSelector() {
    final seconds = controller.taskIntervalSeconds;
    return Row(
      children: [
        Icon(
          Icons.timer_outlined,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text('生成间隔', style: Theme.of(context).textTheme.bodySmall),
        Expanded(
          child: Slider(
            value: seconds.clamp(0.3, 10),
            min: 0.3,
            max: 10,
            divisions: 97,
            label: '${seconds.toStringAsFixed(1)} 秒',
            onChanged: controller.updateTaskInterval,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '${seconds.toStringAsFixed(1)}s',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _primaryActions() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _batchSelector(),
      _intervalSelector(),
      const SizedBox(height: 8),
      // Stays tappable while running: new taps append to the serial queue.
      FilledButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              controller.queueState.isRunning
                  ? '继续排队生成'
                  : (controller.batchCount > 1
                        ? '连续生成 ×${controller.batchCount}'
                        : '立即生成'),
            ),
            const SizedBox(width: 8),
            _anlasBadge(),
          ],
        ),
      ),
      _subscriptionNotice(),
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
              child: Stack(
                children: [
                  Image.file(
                    File(controller.sourceImagePath!),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  // Painted mask preview: the mask PNG is white where the
                  // image will be regenerated, tinted here so the selection
                  // stays visible after leaving the editor.
                  if (controller.mode == GenerationMode.inpaint &&
                      controller.maskImagePath != null)
                    Positioned.fill(
                      child: Image.file(
                        File(controller.maskImagePath!),
                        fit: BoxFit.cover,
                        color: const Color(0x804F6BD8),
                        colorBlendMode: BlendMode.modulate,
                        opacity: const AlwaysStoppedAnimation(0.55),
                        gaplessPlayback: true,
                      ),
                    ),
                ],
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

  /// One-tap retouch from the result panel: switch to inpaint, adopt the
  /// image as source, and open the mask editor immediately.
  Future<void> _inpaintLatest(String imagePath) async {
    controller.updateMode(GenerationMode.inpaint);
    controller.setSourceImage(imagePath);
    await _openMaskEditor();
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
                    tooltip: '悬浮窗模式',
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      setState(() => _assistantMode = _AssistantMode.window);
                    },
                    icon: const Icon(Icons.picture_in_picture_alt_rounded),
                  ),
                  IconButton(
                    tooltip: '缩小为悬浮球',
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      setState(() => _assistantMode = _AssistantMode.bubble);
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
      final count = controller.batchCount;
      final task = await controller.submit();
      if (!mounted) return;
      showCompactSnackBar(
        context,
        icon: Icons.schedule_rounded,
        message: count > 1
            ? '已加入 $count 个任务，串行连续生成'
            : (task.status == GenerationTaskStatus.running
                  ? '已开始生成'
                  : '已加入生成队列'),
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

/// How the prompt assistant is docked on the creation page.
enum _AssistantMode { hidden, bubble, window }
