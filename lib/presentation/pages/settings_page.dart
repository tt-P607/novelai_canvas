import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/backend_mode.dart';
import '../../domain/repositories/secure_credential_store.dart';
import '../controllers/app_settings_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    required this.credentialStore,
  });

  final AppSettingsController controller;
  final SecureCredentialStore credentialStore;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late BackendMode _mode;
  late final TextEditingController _gatewayUrlController;
  late final TextEditingController _novelAiTokenController;
  late final TextEditingController _gatewayKeyController;
  bool _loadingSecrets = true;
  bool _saving = false;
  bool _obscureNovelAiToken = true;
  bool _obscureGatewayKey = true;

  @override
  void initState() {
    super.initState();
    final settings = widget.controller.settings;
    _mode = settings.backendMode;
    _gatewayUrlController = TextEditingController(
      text: settings.gatewayBaseUrl,
    );
    _novelAiTokenController = TextEditingController();
    _gatewayKeyController = TextEditingController();
    _loadSecrets();
  }

  Future<void> _loadSecrets() async {
    final values = await Future.wait([
      widget.credentialStore.read(AppConstants.novelAiCredentialKey),
      widget.credentialStore.read(AppConstants.gatewayCredentialKey),
    ]);
    if (!mounted) return;
    _novelAiTokenController.text = values[0] ?? '';
    _gatewayKeyController.text = values[1] ?? '';
    setState(() => _loadingSecrets = false);
  }

  @override
  void dispose() {
    _gatewayUrlController.dispose();
    _novelAiTokenController.dispose();
    _gatewayKeyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final gatewayUrl = _gatewayUrlController.text.trim();
    if (_mode == BackendMode.gateway) {
      final uri = Uri.tryParse(gatewayUrl);
      if (uri == null ||
          !uri.hasScheme ||
          !uri.hasAuthority ||
          (uri.scheme != 'http' && uri.scheme != 'https')) {
        _showMessage('网关模式需要有效的 http:// 或 https:// 地址。');
        return;
      }
    }

    setState(() => _saving = true);
    await widget.controller.updateBackend(
      backendMode: _mode,
      gatewayBaseUrl: gatewayUrl,
    );
    await _writeOrDelete(
      AppConstants.novelAiCredentialKey,
      _novelAiTokenController.text.trim(),
    );
    await _writeOrDelete(
      AppConstants.gatewayCredentialKey,
      _gatewayKeyController.text.trim(),
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
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        children: [
          Text(
            '连接与安全',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '密钥仅写入系统 Keychain / Keystore，普通设置中只保存后端模式和网关地址。',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('默认后端', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  SegmentedButton<BackendMode>(
                    segments: BackendMode.values
                        .map(
                          (mode) => ButtonSegment(
                            value: mode,
                            label: Text(
                              mode == BackendMode.native ? '原生接口' : '自建网关',
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
                    controller: _gatewayUrlController,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: '网关 Base URL',
                      hintText: 'https://example.com',
                      prefixIcon: Icon(Icons.link_rounded),
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
                  Text('安全凭据', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (_loadingSecrets)
                    const LinearProgressIndicator()
                  else ...[
                    TextField(
                      controller: _novelAiTokenController,
                      obscureText: _obscureNovelAiToken,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'NovelAI Token',
                        prefixIcon: const Icon(Icons.key_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscureNovelAiToken = !_obscureNovelAiToken,
                          ),
                          icon: Icon(
                            _obscureNovelAiToken
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _gatewayKeyController,
                      obscureText: _obscureGatewayKey,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: '网关 API Key（可选）',
                        prefixIcon: const Icon(Icons.vpn_key_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscureGatewayKey = !_obscureGatewayKey,
                          ),
                          icon: Icon(
                            _obscureGatewayKey
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
    );
  }
}
