import 'package:flutter/material.dart';

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
  bool _danbooruToolsEnabled = true;
  bool _showNsfw = false;
  bool _autoApplyPrompt = false;
  bool _loading = true;
  bool _saving = false;
  bool _loadingModels = false;
  bool _obscure = true;
  List<String> _models = const [];

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
    _danbooruToolsEnabled = settings.danbooruToolsEnabled;
    _showNsfw = settings.showNsfw;
    _autoApplyPrompt = settings.autoApplyPrompt;
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
      danbooruToolsEnabled: _danbooruToolsEnabled,
      showNsfw: _showNsfw,
      autoApplyPrompt: _autoApplyPrompt,
      apiKey: _apiKey.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    _message('助手设置与安全凭据已保存。');
  }

  Future<void> _fetchModels() async {
    setState(() => _loadingModels = true);
    try {
      final models = await widget.controller.fetchModels(
        baseUrl: _baseUrl.text,
        apiKey: _apiKey.text,
      );
      if (!mounted) return;
      setState(() {
        _models = models;
        _loadingModels = false;
      });
      if (models.isEmpty) {
        _message('接口返回的模型列表为空。');
        return;
      }
      await _showModelPicker();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingModels = false);
      _message(error.toString().replaceFirst(RegExp(r'^\w+Exception: '), ''));
    }
  }

  Future<void> _showModelPicker() async {
    final search = TextEditingController();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final query = search.text.trim().toLowerCase();
          final filtered = query.isEmpty
              ? _models
              : _models
                    .where((model) => model.toLowerCase().contains(query))
                    .toList();
          return FractionallySizedBox(
            heightFactor: 0.78,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: TextField(
                    controller: search,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: '搜索模型',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('没有匹配的模型'))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final model = filtered[index];
                            return ListTile(
                              title: Text(model),
                              selected: model == _model.text.trim(),
                              onTap: () => Navigator.pop(context, model),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
    search.dispose();
    if (selected != null && mounted) {
      setState(() => _model.text = selected);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('主 Agent 设置')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '模型连接',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _provider,
                        decoration: const InputDecoration(labelText: '供应商名称'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _baseUrl,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'OpenAI 兼容服务地址',
                          hintText: 'https://api.openai.com',
                          helperText: '无需填写 /v1，软件会自动补全接口路径。',
                        ),
                      ),
                      const SizedBox(height: 12),
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
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _model,
                        decoration: InputDecoration(
                          labelText: '模型',
                          hintText: '例如 gpt-4.1-mini',
                          helperText: '可手动填写，也可从接口获取并搜索；附加图片时模型需支持 image_url。',
                          suffixIcon: IconButton(
                            tooltip: '获取模型列表',
                            onPressed: _loadingModels ? null : _fetchModels,
                            icon: _loadingModels
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.manage_search_rounded),
                          ),
                        ),
                      ),
                      if (_models.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _showModelPicker,
                            icon: const Icon(Icons.search_rounded),
                            label: Text('搜索已获取的 ${_models.length} 个模型'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '主 Agent 工具与行为',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text('提示词填入工具始终可用；Danbooru 标签查询是独立工具，可单独关闭。'),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('启用 Danbooru 标签查询工具'),
                        subtitle: const Text('关闭后不会向模型注册标签搜索和相关标签查询工具。'),
                        value: _danbooruToolsEnabled,
                        onChanged: (value) =>
                            setState(() => _danbooruToolsEnabled = value),
                      ),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 180),
                        crossFadeState: _danbooruToolsEnabled
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                        firstChild: Column(
                          children: [
                            TextField(
                              controller: _danbooruUrl,
                              keyboardType: TextInputType.url,
                              decoration: const InputDecoration(
                                labelText: '自定义 Danbooru 工具地址（可选）',
                                helperText: '留空时自动在内置双端点间故障切换',
                              ),
                            ),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('工具允许返回 NSFW 标签'),
                              value: _showNsfw,
                              onChanged: (value) =>
                                  setState(() => _showNsfw = value),
                            ),
                          ],
                        ),
                        secondChild: const SizedBox.shrink(),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Agent 提交的提示词自动填入'),
                        subtitle: const Text('关闭时由用户在对话中点击“一键填入”。'),
                        value: _autoApplyPrompt,
                        onChanged: (value) =>
                            setState(() => _autoApplyPrompt = value),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card.outlined(
                child: ListTile(
                  leading: const Icon(Icons.psychology_alt_rounded),
                  title: const Text('主 Agent 系统 Prompt'),
                  subtitle: Text(
                    widget.controller.settings.prompts.agentPrompt,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: _editAgentPrompt,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 13),
                  child: Text('保存助手设置'),
                ),
              ),
            ],
          ),
  );

  Future<void> _editAgentPrompt() async {
    final editor = TextEditingController(
      text: widget.controller.settings.prompts.agentPrompt,
    );
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('主 Agent 系统 Prompt'),
        content: SizedBox(
          width: 680,
          child: TextField(
            controller: editor,
            minLines: 14,
            maxLines: 24,
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
      await widget.controller.resetAgentPrompt();
    } else {
      await widget.controller.updateAgentPrompt(value);
    }
    if (mounted) setState(() {});
  }
}
