import 'package:flutter/material.dart';

import '../../domain/entities/llm_assistant_settings.dart';
import '../controllers/llm_assistant_settings_controller.dart';

class LlmAssistantSettingsPage extends StatefulWidget {
  const LlmAssistantSettingsPage({super.key, required this.controller});

  final LlmAssistantSettingsController controller;

  @override
  State<LlmAssistantSettingsPage> createState() =>
      _LlmAssistantSettingsPageState();
}

class _LlmAssistantSettingsPageState extends State<LlmAssistantSettingsPage> {
  late final TextEditingController _provider;
  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  late final TextEditingController _danbooruUrl;
  late final TextEditingController _apiKey;
  bool _showNsfw = false;
  bool _loading = true;
  bool _saving = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final settings = widget.controller.settings;
    _provider = TextEditingController(text: settings.providerName);
    _baseUrl = TextEditingController(text: settings.baseUrl);
    _model = TextEditingController(
      text: settings.model.isNotEmpty ? settings.model : settings.visionModel,
    );
    _danbooruUrl = TextEditingController(text: settings.danbooruBaseUrl);
    _apiKey = TextEditingController();
    _showNsfw = settings.showNsfw;
    _loadKey();
  }

  Future<void> _loadKey() async {
    _apiKey.text = await widget.controller.loadApiKey();
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _provider.dispose();
    _baseUrl.dispose();
    _model.dispose();
    _danbooruUrl.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uri = Uri.tryParse(_baseUrl.text.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      _message('请输入有效的 LLM Base URL。');
      return;
    }
    setState(() => _saving = true);
    await widget.controller.saveConnection(
      providerName: _provider.text,
      baseUrl: _baseUrl.text,
      model: _model.text,
      danbooruBaseUrl: _danbooruUrl.text,
      showNsfw: _showNsfw,
      apiKey: _apiKey.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    _message('LLM 设置与安全凭据已保存。');
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('提示词助手设置')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _provider,
                        decoration: const InputDecoration(labelText: '供应商名称'),
                      ),
                      TextField(
                        controller: _baseUrl,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'OpenAI 兼容 Base URL',
                          hintText: 'https://api.openai.com',
                        ),
                      ),
                      TextField(
                        controller: _apiKey,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'LLM API Key',
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                      ),
                      TextField(
                        controller: _model,
                        decoration: const InputDecoration(
                          labelText: '模型',
                          hintText: '例如 gpt-4.1-mini',
                          helperText:
                              '同一个模型用于提示词整理与识图；识图时该模型必须支持 image_url 多模态输入。',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _danbooruUrl,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: '自定义 Danbooru 校准地址（可选）',
                          helperText: '留空时自动在内置双端点间故障切换',
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('允许返回 NSFW 候选标签'),
                        value: _showNsfw,
                        onChanged: (value) => setState(() => _showNsfw = value),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '可编辑 Prompt · v${widget.controller.settings.prompts.version}',
              ),
              const SizedBox(height: 8),
              ...PromptTemplateKind.values.map(_promptTile),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Text('保存助手设置'),
              ),
            ],
          ),
  );

  Widget _promptTile(PromptTemplateKind kind) => Card.outlined(
    child: ListTile(
      title: Text(_promptName(kind)),
      subtitle: Text(
        widget.controller.settings.prompts.valueOf(kind),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () => _editPrompt(kind),
    ),
  );

  Future<void> _editPrompt(PromptTemplateKind kind) async {
    final editor = TextEditingController(
      text: widget.controller.settings.prompts.valueOf(kind),
    );
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_promptName(kind)),
        content: SizedBox(
          width: 640,
          child: TextField(
            controller: editor,
            minLines: 12,
            maxLines: 20,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, '__reset__'),
            child: const Text('恢复默认'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, editor.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    editor.dispose();
    if (value == null) return;
    if (value == '__reset__') {
      await widget.controller.resetPrompt(kind);
    } else {
      await widget.controller.updatePrompt(kind, value);
    }
    if (mounted) setState(() {});
  }

  String _promptName(PromptTemplateKind kind) => switch (kind) {
    PromptTemplateKind.keywordExtraction => '关键词提取 Prompt',
    PromptTemplateKind.promptComposition => '提示词整理 Prompt',
    PromptTemplateKind.visionAnalysis => 'Vision 识图 Prompt',
    PromptTemplateKind.jsonRepair => 'JSON 修复 Prompt',
  };
}
