import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/backend_mode.dart';
import '../../domain/repositories/secure_credential_store.dart';
import '../controllers/app_settings_controller.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.controller,
    required this.credentialStore,
  });

  final AppSettingsController controller;
  final SecureCredentialStore credentialStore;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _endpointController;
  late final TextEditingController _apiKeyController;
  BackendMode _mode = BackendMode.native;
  bool _saving = false;
  bool _loadingSecret = true;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _mode = widget.controller.settings.backendMode;
    _endpointController = TextEditingController();
    _apiKeyController = TextEditingController();
    _refreshEditors();
  }

  String _endpointFor(BackendMode mode) {
    final value = widget.controller.settings.endpointBaseUrlFor(mode).trim();
    if (mode == BackendMode.native && value.isEmpty) {
      return AppConstants.nativeBaseUrl;
    }
    return value;
  }

  String _credentialKeyFor(BackendMode mode) => switch (mode) {
    BackendMode.native => AppConstants.nativeImageApiKey,
    BackendMode.gateway => AppConstants.gatewayImageApiKey,
  };

  Future<void> _refreshEditors() async {
    _endpointController.text = _endpointFor(_mode);
    final key = await widget.credentialStore.read(_credentialKeyFor(_mode));
    _apiKeyController.text = key ?? '';
    if (mounted) setState(() => _loadingSecret = false);
  }

  Future<void> _onModeChanged(BackendMode next) async {
    if (next == _mode) return;
    // Auto-save the current URL/key before switching so the user does not
    // lose what they typed when they forget to press 进入绘境.
    await _autoSaveCurrentMode();
    setState(() {
      _mode = next;
      _loadingSecret = true;
    });
    // Persist the mode immediately so the onboarding flow ends in the right
    // state even if the user navigates away before pressing 进入绘境.
    await widget.controller.switchBackendMode(next);
    await _refreshEditors();
  }

  /// Saves the URL and key currently visible in the editors without
  /// validation, so switching modes preserves the user's input.
  Future<void> _autoSaveCurrentMode() async {
    final endpointUrl = _endpointController.text.trim();
    await widget.controller.updateBackend(
      backendMode: _mode,
      endpointBaseUrl: endpointUrl,
    );
    final key = _apiKeyController.text.trim();
    final credentialKey = _credentialKeyFor(_mode);
    if (key.isEmpty) {
      await widget.credentialStore.delete(credentialKey);
    } else {
      await widget.credentialStore.write(key: credentialKey, value: key);
    }
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final key = _apiKeyController.text.trim();
    final credentialKey = _credentialKeyFor(_mode);
    if (key.isEmpty) {
      await widget.credentialStore.delete(credentialKey);
    } else {
      await widget.credentialStore.write(key: credentialKey, value: key);
    }
    await widget.controller.completeOnboarding(
      backendMode: _mode,
      endpointBaseUrl: _endpointController.text,
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: colors.onPrimaryContainer,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'NovelAI Canvas',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                      ),
                    ),
                    Text(
                      '绘境',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '原生与 OpenAI 各自独立保存 URL 和密钥；切换上方按钮即可编辑对应后端的配置，后续可随时在设置中修改。',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SegmentedButton<BackendMode>(
                      segments: BackendMode.values
                          .map(
                            (mode) => ButtonSegment(
                              value: mode,
                              icon: Icon(
                                mode == BackendMode.native
                                    ? Icons.bolt_rounded
                                    : Icons.hub_rounded,
                              ),
                              label: Text(
                                mode == BackendMode.native
                                    ? '原生接口'
                                    : 'OpenAI 接口',
                              ),
                            ),
                          )
                          .toList(),
                      selected: {_mode},
                      onSelectionChanged: (selection) =>
                          _onModeChanged(selection.first),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _endpointController,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: '接口 URL',
                        hintText: _mode == BackendMode.native
                            ? AppConstants.nativeBaseUrl
                            : 'https://example.com',
                        helperText: _mode == BackendMode.native
                            ? '默认使用 NovelAI 官方地址；改为 novelai-gateway 根地址时会自动补全 /_api。'
                            : 'OpenAI 接口必须填写兼容服务地址，无需在末尾填写 /v1。',
                        prefixIcon: const Icon(Icons.link_rounded),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return '接口 URL 不能为空';
                        final uri = Uri.tryParse(text);
                        if (uri == null ||
                            !uri.hasScheme ||
                            !uri.hasAuthority ||
                            (uri.scheme != 'http' && uri.scheme != 'https')) {
                          return '请输入完整的 http:// 或 https:// 地址';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    if (_loadingSecret)
                      const LinearProgressIndicator()
                    else
                      TextFormField(
                        controller: _apiKeyController,
                        obscureText: _obscure,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: '密钥',
                          hintText: _mode == BackendMode.native
                              ? 'NovelAI Token'
                              : 'API Key（按服务要求填写）',
                          prefixIcon: const Icon(Icons.key_rounded),
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
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: _saving || _loadingSecret ? null : _continue,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward_rounded),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('进入绘境'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
