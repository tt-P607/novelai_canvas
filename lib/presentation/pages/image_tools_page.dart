import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/repositories/image_tools_repository.dart';
import '../controllers/image_tools_controller.dart';
import '../widgets/fullscreen_image_preview.dart';

class ImageToolsPage extends StatefulWidget {
  const ImageToolsPage({super.key, required this.controller});

  final ImageToolsController controller;

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
  Widget build(BuildContext context) => SafeArea(
    child: ListenableBuilder(
      listenable: controller,
      builder: (context, _) => CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('图像工具')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverList.list(
              children: [
                _sourceCard(),
                const SizedBox(height: 16),
                _upscaleCard(),
                const SizedBox(height: 16),
                _directorCard(),
                const SizedBox(height: 16),
                _tagCard(),
                if (controller.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(controller.errorMessage!),
                    ),
                  ),
                ],
                if (controller.resultBytes != null) ...[
                  const SizedBox(height: 16),
                  _comparisonCard(),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _comparisonCard() => Card(
    child: Padding(
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
                  label: Text('${controller.anlasCost} A'),
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
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: controller.useResultAsSource,
              icon: const Icon(Icons.redo_rounded),
              label: const Text('使用结果继续处理'),
            ),
          ),
        ],
      ),
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

  Widget _sourceCard() => Card(
    child: Padding(
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
    ),
  );

  Widget _upscaleCard() => Card(
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

  Widget _directorCard() => Card(
    child: Padding(
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
              DropdownButtonFormField<String>(
                initialValue: controller.selectedEmotion,
                decoration: const InputDecoration(
                  labelText: '表情',
                  border: OutlineInputBorder(),
                ),
                items: directorEmotionPrompts.keys
                    .map(
                      (label) =>
                          DropdownMenuItem(value: label, child: Text(label)),
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
            onPressed: controller.isRunning
                ? null
                : controller.applyDirectorTool,
            icon: const Icon(Icons.auto_fix_high_rounded),
            label: Text(controller.isRunning ? '处理中…' : '执行导演工具'),
          ),
        ],
      ),
    ),
  );

  Widget _tagCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('标签建议', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            onChanged: controller.updatePrompt,
            decoration: const InputDecoration(
              labelText: '输入提示词，例如 1girl',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: controller.isRunning
                ? null
                : () => controller.suggestTags(model: 'nai-diffusion-3'),
            child: const Text('获取标签建议'),
          ),
          if (controller.suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: controller.suggestions
                  .map(
                    (tag) => InputChip(
                      label: Text(tag.tag),
                      avatar: Text('${(tag.confidence * 100).round()}%'),
                      onPressed: () {
                        _promptController.text = [
                          _promptController.text.trim(),
                          tag.tag,
                        ].where((value) => value.isNotEmpty).join(', ');
                        controller.updatePrompt(_promptController.text);
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    ),
  );

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
