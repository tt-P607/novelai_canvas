import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/prompt_assistant.dart';
import '../controllers/generation_controller.dart';
import '../controllers/llm_assistant_settings_controller.dart';
import '../controllers/prompt_assistant_controller.dart';
import 'llm_assistant_settings_page.dart';

class PromptAssistantPage extends StatefulWidget {
  const PromptAssistantPage({
    super.key,
    required this.controller,
    required this.settingsController,
    required this.generationController,
  });

  final PromptAssistantController controller;
  final LlmAssistantSettingsController settingsController;
  final GenerationController generationController;

  @override
  State<PromptAssistantPage> createState() => _PromptAssistantPageState();
}

class _PromptAssistantPageState extends State<PromptAssistantPage> {
  late final TextEditingController _description;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _description = TextEditingController(text: widget.controller.description);
    widget.controller.addListener(_sync);
  }

  void _sync() {
    if (_description.text != widget.controller.description) {
      _description.text = widget.controller.description;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('提示词助手'),
      actions: [
        IconButton(
          tooltip: '助手设置',
          onPressed: _openSettings,
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _description,
                      minLines: 5,
                      maxLines: 12,
                      onChanged: widget.controller.updateDescription,
                      decoration: const InputDecoration(
                        labelText: '自然语言画面描述',
                        hintText: '例如：黄昏海边，一位银发少女回头微笑，电影感逆光……',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.controller.imagePath != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(widget.controller.imagePath!),
                          height: 180,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('选择识图图片'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: widget.controller.isRunning
                              ? null
                              : widget.controller.analyzeVision,
                          icon: const Icon(Icons.visibility_rounded),
                          label: const Text('Vision 识图'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '识图要求：所配置的模型必须真正支持 OpenAI image_url 多模态输入；仅名称中带 Vision 并不代表一定可用。',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: widget.controller.isRunning ? null : _generate,
              icon: widget.controller.isRunning
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_fix_high_rounded),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Text('提取关键词、校准并整理'),
              ),
            ),
            if (widget.controller.status.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(widget.controller.status),
                ),
              ),
            ],
            if (widget.controller.errorMessage != null) ...[
              const SizedBox(height: 12),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.error_outline_rounded),
                  title: Text(widget.controller.errorMessage!),
                ),
              ),
            ],
            if (widget.controller.keywords != null) ...[
              const SizedBox(height: 12),
              _keywordCard(widget.controller.keywords!),
            ],
            if (widget.controller.tagPool != null) ...[
              const SizedBox(height: 12),
              _tagPoolCard(widget.controller.tagPool!),
            ],
            if (widget.controller.result != null) ...[
              const SizedBox(height: 12),
              _resultCard(widget.controller.result!),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _keywordCard(ExtractedKeywords value) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('检索关键词', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _chips('角色', value.characters),
          _chips('场景', value.scene),
          _chips('风格', value.style),
          if (value.nsfw.isNotEmpty) _chips('NSFW', value.nsfw),
        ],
      ),
    ),
  );

  Widget _tagPoolCard(DanbooruTagPool pool) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Danbooru 真实候选池',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text('共 ${pool.all.length} 个 search / related 标签，点击可查看元数据。'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: pool.all
                .take(80)
                .map(
                  (tag) => ActionChip(
                    label: Text(tag.novelAiTag),
                    avatar: tag.isNsfw
                        ? const Icon(Icons.warning_amber_rounded, size: 16)
                        : null,
                    onPressed: () => _showTag(tag),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    ),
  );

  Widget _resultCard(PromptAssistantResult result) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('整理结果', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SelectableText('正向：${result.positive}'),
          const SizedBox(height: 8),
          SelectableText('负向：${result.negative}'),
          for (final entry in result.characters.indexed) ...[
            const Divider(height: 24),
            SelectableText('角色 ${entry.$1 + 1}：${entry.$2.prompt}'),
            if (entry.$2.negativePrompt.isNotEmpty)
              SelectableText('角色负向：${entry.$2.negativePrompt}'),
          ],
          if (result.notes.isNotEmpty) ...[
            const Divider(height: 24),
            Text(result.notes),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _apply,
            icon: const Icon(Icons.input_rounded),
            label: const Text('确认并回填创作页'),
          ),
          const SizedBox(height: 6),
          const Text('此操作只更新提示词草稿，不会点击生成。'),
        ],
      ),
    ),
  );

  Widget _chips(String label, List<String> values) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 48, child: Text('$label：')),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: values
                  .map((value) => Chip(label: Text(value)))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) widget.controller.setImagePath(image.path);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) =>
            LlmAssistantSettingsPage(controller: widget.settingsController),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _generate() => widget.controller.generate(
    currentPositive: widget.generationController.prompt,
    currentNegative: widget.generationController.negativePrompt,
  );

  void _apply() {
    final result = widget.controller.result!;
    widget.generationController.applyAssistantResult(result);
    Navigator.of(context).pop();
  }

  void _showTag(DanbooruTag tag) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tag.novelAiTag, style: Theme.of(context).textTheme.titleLarge),
            Text(tag.tag),
            const SizedBox(height: 12),
            Text('中文名：${tag.cnName.isEmpty ? '未知' : tag.cnName}'),
            Text('分类：${tag.category.isEmpty ? '未知' : tag.category}'),
            Text('热度：${tag.count}'),
            Text('分数：${tag.score.toStringAsFixed(4)}'),
            Text('来源：${tag.origin}'),
            if (tag.wiki.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(tag.wiki, maxLines: 8, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}
