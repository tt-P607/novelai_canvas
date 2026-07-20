import 'package:flutter/material.dart';

import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/backend_mode.dart';
import '../../domain/repositories/secure_credential_store.dart';
import '../controllers/app_settings_controller.dart';
import '../controllers/data_management_controller.dart';
import '../controllers/llm_assistant_settings_controller.dart';
import 'llm_assistant_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    required this.credentialStore,
    required this.dataManagementController,
    required this.llmSettingsController,
  });

  final AppSettingsController controller;
  final SecureCredentialStore credentialStore;
  final DataManagementController dataManagementController;
  final LlmAssistantSettingsController llmSettingsController;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late BackendMode _mode;
  late final TextEditingController _endpointUrlController;
  late final TextEditingController _apiKeyController;
  bool _loadingSecrets = true;
  bool _saving = false;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    final settings = widget.controller.settings;
    _mode = settings.backendMode;
    _endpointUrlController = TextEditingController(
      text: settings.endpointBaseUrl,
    );
    _apiKeyController = TextEditingController();
    _loadSecret();
  }

  Future<void> _loadSecret() async {
    final value = await widget.credentialStore.read(
      AppConstants.imageApiCredentialKey,
    );
    if (!mounted) return;
    _apiKeyController.text = value ?? '';
    setState(() => _loadingSecrets = false);
  }

  @override
  void dispose() {
    _endpointUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final endpointUrl = _endpointUrlController.text.trim();
    if (endpointUrl.isEmpty) {
      _showMessage('接口 URL 不能为空。');
      return;
    }
    final uri = Uri.tryParse(endpointUrl);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      _showMessage('接口 URL 需要是完整的 http:// 或 https:// 地址。');
      return;
    }

    setState(() => _saving = true);
    await widget.controller.updateBackend(
      backendMode: _mode,
      endpointBaseUrl: endpointUrl,
    );
    await _writeOrDelete(
      AppConstants.imageApiCredentialKey,
      _apiKeyController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    _showMessage('连接设置已安全保存。');
  }

  Future<void> _writeOrDelete(String key, String value) {
    if (value.isEmpty) return widget.credentialStore.delete(key);
    return widget.credentialStore.write(key: key, value: value);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('设置')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverList.list(
              children: [
                _SettingsHero(colors: colors),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '接口格式',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        SegmentedButton<BackendMode>(
                          segments: BackendMode.values
                              .map(
                                (mode) => ButtonSegment(
                                  value: mode,
                                  label: Text(
                                    mode == BackendMode.native
                                        ? '原生接口'
                                        : 'OpenAI 接口',
                                  ),
                                ),
                              )
                              .toList(),
                          selected: {_mode},
                          onSelectionChanged: (value) {
                            setState(() => _mode = value.first);
                          },
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _endpointUrlController,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: '接口 URL',
                            hintText: _mode == BackendMode.native
                                ? AppConstants.nativeBaseUrl
                                : 'https://example.com',
                            helperText: _mode == BackendMode.native
                                ? '可填写根地址或完整生成地址；软件会移除 /ai/generate-image，再按请求自动补全 /_api 和具体路径。'
                                : '填写 OpenAI 兼容服务地址，无需在末尾填写 /v1。',
                            prefixIcon: const Icon(Icons.link_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '接口密钥',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        if (_loadingSecrets)
                          const LinearProgressIndicator()
                        else ...[
                          TextField(
                            controller: _apiKeyController,
                            obscureText: _obscureApiKey,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: InputDecoration(
                              labelText: '密钥',
                              hintText: _mode == BackendMode.native
                                  ? 'NovelAI Token'
                                  : 'API Key（按服务要求填写）',
                              prefixIcon: const Icon(Icons.key_rounded),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscureApiKey = !_obscureApiKey,
                                ),
                                icon: Icon(
                                  _obscureApiKey
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.auto_awesome_rounded,
                      color: colors.primary,
                    ),
                    title: const Text('提示词助手'),
                    subtitle: const Text('单模型对话、图片附件、Danbooru 工具、会话归档与自动填入'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (context) => LlmAssistantSettingsPage(
                          controller: widget.llmSettingsController,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _DataManagementCard(
                  controller: widget.dataManagementController,
                  showMessage: _showMessage,
                ),
                const SizedBox(height: 16),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final version = snapshot.data == null
                        ? '正在读取版本…'
                        : '${snapshot.data!.version}+${snapshot.data!.buildNumber}';
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.info_outline_rounded),
                        title: const Text(AppConstants.appName),
                        subtitle: Text(
                          '版本 $version\n包名 com.elysia.novelaicanvas',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _saving || _loadingSecrets ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 13),
                    child: Text('保存设置'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsHero extends StatelessWidget {
  const _SettingsHero({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: colors.primaryContainer.withValues(alpha: 0.32),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: colors.primary.withValues(alpha: 0.22)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_moon_rounded, color: colors.primary, size: 30),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '连接与隐私',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                '上方仅切换请求格式；URL 与密钥共用一套配置，并只保存在本机安全存储中。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DataManagementCard extends StatelessWidget {
  const _DataManagementCard({
    required this.controller,
    required this.showMessage,
  });

  final DataManagementController controller;
  final ValueChanged<String> showMessage;

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String content,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('数据与备份', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              '备份包含非敏感设置、Agent Prompt 和生成历史参数；不会导出任何 API Key 或 Token。',
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: controller.busy
                  ? null
                  : () async {
                      final path = await controller.exportBackup();
                      if (path != null) showMessage('备份已保存到：$path');
                      if (controller.errorMessage != null) {
                        showMessage('导出失败：${controller.errorMessage}');
                      }
                    },
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('导出备份'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: controller.busy
                  ? null
                  : () async {
                      final confirmed = await _confirm(
                        context,
                        title: '导入备份',
                        content:
                            '将恢复普通设置、LLM Prompt 和历史参数。同 ID 历史默认保留本机版本，安全凭据不会被修改。',
                      );
                      if (!confirmed) return;
                      final count = await controller.importBackup();
                      if (count != null) showMessage('已读取并导入 $count 条历史记录。');
                      if (controller.errorMessage != null) {
                        showMessage('导入失败：${controller.errorMessage}');
                      }
                    },
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('导入备份'),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: controller.busy
                  ? null
                  : () async {
                      final confirmed = await _confirm(
                        context,
                        title: '清除全部安全凭据',
                        content:
                            '将从系统 Keychain / Keystore 删除生图接口密钥和 LLM Key。此操作不可撤销。',
                      );
                      if (!confirmed) return;
                      try {
                        await controller.clearCredentials();
                        showMessage('全部安全凭据已清除。');
                      } catch (_) {
                        showMessage('清除失败：${controller.errorMessage}');
                      }
                    },
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('清除全部安全凭据'),
            ),
            if (controller.busy) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    ),
  );
}
