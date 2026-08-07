import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/backend_mode.dart';
import '../../domain/entities/director_emotion.dart';
import '../../domain/repositories/image_tools_repository.dart';
import '../controllers/generation_controller.dart';
import '../controllers/image_tools_controller.dart';
import '../widgets/anlas_icon.dart';
import '../widgets/compact_snack_bar.dart';
import '../widgets/fullscreen_image_preview.dart';
import '../widgets/glass/liquid_glass.dart';

class ImageToolsPage extends StatefulWidget {
  const ImageToolsPage({
    super.key,
    required this.controller,
    this.generationController,
  });

  final ImageToolsController controller;

  /// Used to read and refresh the Anlas balance badge. Null in tests.
  final GenerationController? generationController;

  @override
  State<ImageToolsPage> createState() => _ImageToolsPageState();
}

class _ImageToolsPageState extends State<ImageToolsPage> {
  final ImagePicker _picker = ImagePicker();
  late final TextEditingController _promptController;

  ImageToolsController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(text: controller.prompt);
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gen = widget.generationController;
    final listenables = gen == null
        ? controller
        : Listenable.merge([controller, gen]);
    return SafeArea(
      child: ListenableBuilder(
        listenable: listenables,
        builder: (context, _) => CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('图像工具'),
                  if (gen != null && gen.backendMode == BackendMode.native) ...[
                    const SizedBox(width: 10),
                    _anlasBalanceBadge(gen),
                  ],
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList.list(
                children: [
                  _sourceCard(),
                  const SizedBox(height: 16),
                  _stripMetadataCard(),
                  const SizedBox(height: 16),
                  _compressCard(),
                  const SizedBox(height: 16),
                  _upscaleCard(),
                  const SizedBox(height: 16),
                  _directorCard(),
                  if (controller.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    LiquidGlass(
                      padding: const EdgeInsets.all(16),
                      child: Material(
                        type: MaterialType.transparency,
                        child: Text(
                          controller.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (controller.resultBytes != null) ...[
                    const SizedBox(height: 16),
                    _comparisonCard(),
                  ],
                  if (controller.metadata != null) ...[
                    const SizedBox(height: 16),
                    _metadataCard(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshAnlasWithFeedback(GenerationController gen) async {
    final outcome = await gen.refreshSubscription(force: true);
    if (!mounted) return;
    final (icon, message) = switch (outcome) {
      RefreshOutcome.updated => (Icons.check_circle_rounded, '余额已更新'),
      RefreshOutcome.unchanged => (Icons.check_circle_outline_rounded, '余额未变化'),
      RefreshOutcome.busy => (Icons.hourglass_top_rounded, '正在刷新…'),
      RefreshOutcome.failed => (
        Icons.error_outline_rounded,
        gen.subscriptionError ?? '刷新失败',
      ),
      RefreshOutcome.skipped => (Icons.info_outline_rounded, '当前后端不支持查询余额'),
    };
    showCompactSnackBar(context, icon: icon, message: message);
  }

  Widget _anlasBalanceBadge(GenerationController gen) {
    final colors = Theme.of(context).colorScheme;
    final known = gen.anlasKnown;
    final errored = gen.anlasError != null;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _refreshAnlasWithFeedback(gen),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: errored
              ? colors.errorContainer.withValues(alpha: 0.7)
              : colors.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              known ? '${gen.anlas}' : '?',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: errored ? colors.onErrorContainer : kAnlasColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            if (errored)
              Icon(
                Icons.error_outline_rounded,
                size: 14,
                color: colors.onErrorContainer,
              )
            else
              const AnlasIcon(size: 14),
          ],
        ),
      ),
    );
  }

  Widget _comparisonCard() => LiquidGlass(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '处理对比',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (controller.anlasCost != null)
              Chip(
                visualDensity: VisualDensity.compact,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnlasIcon(size: 12),
                    const SizedBox(width: 4),
                    Text('${controller.anlasCost}'),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _comparisonImage(
                label: '原图',
                child: Image.file(
                  File(controller.sourceImagePath!),
                  height: 220,
                  fit: BoxFit.contain,
                ),
                onTap: () => FullscreenImagePreview.showFile(
                  context,
                  controller.sourceImagePath!,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _comparisonImage(
                label: '结果',
                child: Image.memory(
                  controller.resultBytes!,
                  height: 220,
                  fit: BoxFit.contain,
                ),
                onTap: () => FullscreenImagePreview.showMemory(
                  context,
                  controller.resultBytes!,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: controller.useResultAsSource,
                icon: const Icon(Icons.redo_rounded),
                label: const Text('继续处理'),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: () => _saveToGallery(context),
              icon: const Icon(Icons.save_alt_rounded),
              label: const Text('保存'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _comparisonImage({
    required String label,
    required Widget child,
    required VoidCallback onTap,
  }) => Column(
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Text(label, style: Theme.of(context).textTheme.labelLarge),
      ),
      const SizedBox(height: 6),
      InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    ],
  );

  Widget _sourceCard() => LiquidGlass(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('源图片', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (controller.sourceImagePath != null)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => FullscreenImagePreview.showFile(
              context,
              controller.sourceImagePath!,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(controller.sourceImagePath!),
                height: 220,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(controller.sourceImagePath == null ? '选择图片' : '更换图片'),
        ),
        if (controller.sourceImagePath != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.straighten_rounded, size: 18),
              const SizedBox(width: 8),
              Text('已识别 ${controller.width} × ${controller.height}'),
            ],
          ),
        ],
      ],
    ),
  );

  /// Local-only NAI metadata tools. Extracting reads the tEXt chunks plus the
  /// alpha-LSB gzip payload; stripping scrubs both, so users can inspect or
  /// scrub a PNG's embedded generation metadata anywhere.
  Widget _stripMetadataCard() => LiquidGlass(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NAI 元数据', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          '读取或移除 PNG 的 tEXt 块与 alpha 通道 LSB 隐写（NAI 提示词、参数与模型签名）。'
          '纯客户端操作，不消耗 Anlas、不走网络。',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: controller.isRunning
                    ? null
                    : controller.extractMetadata,
                icon: const Icon(Icons.manage_search_rounded),
                label: const Text('提取'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: controller.isRunning
                    ? null
                    : controller.stripMetadata,
                icon: const Icon(Icons.cleaning_services_rounded),
                label: const Text('剥离'),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  /// Renders the NAI metadata extracted from the source image as readable
  /// fields, with the raw JSON payload collapsed behind an expander.
  Widget _metadataCard() {
    final meta = controller.metadata!;
    // The Comment chunk usually holds the whole NAI JSON blob; skip it here so
    // it is not dumped as an unreadable wall of text — it lives in the raw
    // JSON expander below instead.
    final chunks = meta.textChunks.entries
        .where((e) => e.key != 'Comment')
        .toList();
    final hasChunks = chunks.isNotEmpty;
    final comment = meta.textChunks['Comment'];
    final hasJson =
        (meta.stealthJson != null && meta.stealthJson!.isNotEmpty) ||
        (comment != null && comment.isNotEmpty);
    final hasReadable =
        meta.prompt != null ||
        meta.negativePrompt != null ||
        meta.sampler != null ||
        meta.steps != null ||
        meta.seed != null ||
        meta.width != null ||
        meta.height != null ||
        meta.scale != null ||
        meta.noiseSchedule != null ||
        meta.signedHash != null;
    if (!hasReadable && !hasChunks && !hasJson) {
      return LiquidGlass(
        padding: const EdgeInsets.all(16),
        child: Text(
          '未检测到 NAI 元数据。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final params = <(String, String)>[
      if (meta.sampler != null) ('采样器', meta.sampler!),
      if (meta.steps != null) ('步数', '${meta.steps}'),
      if (meta.seed != null) ('种子', '${meta.seed}'),
      if (meta.width != null && meta.height != null)
        ('尺寸', '${meta.width} × ${meta.height}'),
      if (meta.scale != null) ('CFG', '${meta.scale}'),
      if (meta.noiseSchedule != null) ('噪声调度', meta.noiseSchedule!),
      if (meta.signedHash != null) ('模型签名', meta.signedHash!),
    ];

    return LiquidGlass(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('提取的元数据', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (meta.prompt != null) ...[
            const Text('提示词', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            SelectableText(
              meta.prompt!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
          ],
          if (meta.negativePrompt != null) ...[
            const Text('负面词', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            SelectableText(
              meta.negativePrompt!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
          ],
          if (params.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, value) in params)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('$label $value'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (hasChunks) ...[
            const Text('文本块', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            for (final entry in chunks)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SelectableText(
                  '${entry.key}: ${entry.value}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 10),
          ],
          if (hasJson) ...[
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: const Text(
                  '原始 JSON',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                shape: const Border(),
                collapsedShape: const Border(),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: [
                  SelectableText(
                    meta.stealthJson ?? comment ?? '',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _upscaleCard() => LiquidGlass(
    child: ListTile(
      leading: const Icon(Icons.zoom_out_map_rounded),
      title: const Text('4× 图片放大'),
      subtitle: const Text('宽高各放大 4 倍，预计固定消耗 7 Anlas'),
      trailing: FilledButton(
        onPressed: controller.isRunning ? null : controller.upscale,
        child: const Text('放大'),
      ),
    ),
  );

  Widget _directorCard() => LiquidGlass(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('导演工具', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<DirectorTool>(
          initialValue: controller.selectedTool,
          decoration: const InputDecoration(
            labelText: '处理类型',
            border: OutlineInputBorder(),
          ),
          items: DirectorTool.values
              .map(
                (tool) => DropdownMenuItem(
                  value: tool,
                  child: Text(_directorLabel(tool)),
                ),
              )
              .toList(),
          onChanged: (value) => controller.selectTool(value!),
        ),
        if (controller.selectedTool == DirectorTool.backgroundRemoval)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text('注意：精细抠图预计消耗 65–200 Anlas。'),
          ),
        if ({
          DirectorTool.colorize,
          DirectorTool.emotion,
        }.contains(controller.selectedTool)) ...[
          const SizedBox(height: 12),
          if (controller.selectedTool == DirectorTool.emotion) ...[
            DropdownButtonFormField<DirectorEmotion>(
              initialValue: controller.selectedEmotion,
              decoration: const InputDecoration(
                labelText: '表情',
                border: OutlineInputBorder(),
              ),
              items: DirectorEmotion.values
                  .map(
                    (emotion) => DropdownMenuItem(
                      value: emotion,
                      child: Text(emotion.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) controller.selectEmotion(value);
              },
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _promptController,
            onChanged: controller.updatePrompt,
            decoration: InputDecoration(
              labelText: controller.selectedTool == DirectorTool.emotion
                  ? '附加提示词（可选）'
                  : '上色提示词（可选）',
              border: const OutlineInputBorder(),
            ),
          ),
          Text('Defry ${controller.defry}'),
          Slider(
            value: controller.defry.toDouble(),
            min: 0,
            max: 5,
            divisions: 5,
            onChanged: controller.updateDefry,
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: controller.isRunning ? null : controller.applyDirectorTool,
          icon: const Icon(Icons.auto_fix_high_rounded),
          label: Text(controller.isRunning ? '处理中…' : '执行导演工具'),
        ),
      ],
    ),
  );

  Widget _compressCard() {
    final srcW = controller.width;
    final srcH = controller.height;
    final alignW = ((srcW.clamp(64, 1600) + 32) ~/ 64 * 64).clamp(64, 1600);
    final alignH = ((srcH.clamp(64, 1600) + 32) ~/ 64 * 64).clamp(64, 1600);
    final needsAlign = alignW != srcW || alignH != srcH;
    final pixels = srcW * srcH;
    const pixelCap = 1048576;
    final needsFreeTier = pixels > pixelCap;
    // Preview the free-tier target size.
    int freeW = alignW;
    int freeH = alignH;
    if (needsFreeTier) {
      final scale = sqrt(pixelCap / pixels);
      freeW = ((srcW * scale).round()).clamp(64, 1600);
      freeH = ((srcH * scale).round()).clamp(64, 1600);
      freeW = ((freeW + 32) ~/ 64 * 64).clamp(64, 1600);
      freeH = ((freeH + 32) ~/ 64 * 64).clamp(64, 1600);
      while (freeW * freeH > pixelCap) {
        if (freeW >= freeH) {
          freeW -= 64;
        } else {
          freeH -= 64;
        }
      }
    }
    return LiquidGlass(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('压缩画幅', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            '纯客户端操作，不消耗 Anlas、不走网络。'
            '将源图用高质量重采样缩放到目标尺寸。',
          ),
          const SizedBox(height: 12),
          if (controller.sourceImagePath != null) ...[
            Row(
              children: [
                const Icon(Icons.straighten_rounded, size: 18),
                const SizedBox(width: 8),
                Text('当前 $srcW × $srcH'),
              ],
            ),
            const SizedBox(height: 8),
          ],
          // Align to 64
          if (controller.sourceImagePath != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      needsAlign ? '对齐 64 → $alignW × $alignH' : '已对齐 64 像素',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: controller.isRunning || !needsAlign
                        ? null
                        : () => controller.compressImage(CompressMode.align64),
                    icon: const Icon(Icons.grid_4x4_rounded, size: 18),
                    label: const Text('对齐 64'),
                  ),
                ],
              ),
            ),
          // Free tier
          if (controller.sourceImagePath != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    needsFreeTier
                        ? '压到免费 → $freeW × $freeH（≤ 1M 像素）'
                        : '已在免费范围内',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: controller.isRunning || !needsFreeTier
                      ? null
                      : () => controller.compressImage(CompressMode.freeTier),
                  icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                  label: const Text('压到免费'),
                ),
              ],
            ),
          if (controller.isRunning) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  Future<void> _saveToGallery(BuildContext context) async {
    final path = controller.resultPath;
    if (path == null || path.isEmpty) return;
    try {
      await ImageGallerySaverPlus.saveFile(path);
      if (!context.mounted) return;
      showCompactSnackBar(
        context,
        icon: Icons.check_circle_rounded,
        message: '已保存到相册',
      );
    } catch (_) {
      if (!context.mounted) return;
      showCompactSnackBar(
        context,
        icon: Icons.error_outline_rounded,
        message: '保存失败',
      );
    }
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) await controller.setSourceImage(image.path);
  }

  String _directorLabel(DirectorTool tool) => switch (tool) {
    DirectorTool.declutter => '去杂物',
    DirectorTool.backgroundRemoval => '精细抠图',
    DirectorTool.lineart => '提取线稿',
    DirectorTool.sketch => '转铅笔画',
    DirectorTool.colorize => '线稿上色',
    DirectorTool.emotion => '改变表情',
  };
}
