import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/repositories/image_tools_repository.dart';
import '../controllers/image_tools_controller.dart';

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
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Image.memory(
                          controller.resultBytes!,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                        ListTile(
                          leading: const Icon(Icons.save_alt_rounded),
                          title: const Text('处理结果已保存到应用目录'),
                          subtitle: Text(
                            controller.resultPath ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: controller.anlasCost == null
                              ? null
                              : Chip(label: Text('${controller.anlasCost} A')),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(controller.sourceImagePath!),
                height: 220,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(controller.sourceImagePath == null ? '选择图片' : '更换图片'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: '${controller.width}x${controller.height}',
            decoration: const InputDecoration(
              labelText: '源图尺寸',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: '512x512', child: Text('512 × 512')),
              DropdownMenuItem(value: '832x1216', child: Text('832 × 1216')),
              DropdownMenuItem(value: '1216x832', child: Text('1216 × 832')),
              DropdownMenuItem(value: '1024x1024', child: Text('1024 × 1024')),
            ],
            onChanged: (value) {
              final parts = value!.split('x');
              controller.updateSize(
                width: int.parse(parts.first),
                height: int.parse(parts.last),
              );
            },
          ),
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
            TextField(
              controller: _promptController,
              onChanged: controller.updatePrompt,
              decoration: const InputDecoration(
                labelText: '处理提示词',
                border: OutlineInputBorder(),
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
    if (image != null) controller.setSourceImage(image.path);
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
