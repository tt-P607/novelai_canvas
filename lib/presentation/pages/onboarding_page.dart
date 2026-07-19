import 'package:flutter/material.dart';

import '../../core/network/backend_mode.dart';
import '../controllers/app_settings_controller.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.controller});

  final AppSettingsController controller;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _gatewayController;
  BackendMode _mode = BackendMode.native;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.controller.settings.backendMode;
    _gatewayController = TextEditingController(
      text: widget.controller.settings.gatewayBaseUrl,
    );
  }

  @override
  void dispose() {
    _gatewayController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.controller.completeOnboarding(
      backendMode: _mode,
      gatewayBaseUrl: _gatewayController.text,
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
                      '先选择默认连接方式。后续可随时在设置中切换，原生接口与自建网关配置互不覆盖。',
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
                                mode == BackendMode.native ? '原生接口' : '自建网关',
                              ),
                            ),
                          )
                          .toList(),
                      selected: {_mode},
                      onSelectionChanged: (selection) {
                        setState(() => _mode = selection.first);
                      },
                    ),
                    const SizedBox(height: 20),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _mode == BackendMode.gateway
                          ? TextFormField(
                              key: const ValueKey('gateway-url'),
                              controller: _gatewayController,
                              keyboardType: TextInputType.url,
                              autocorrect: false,
                              decoration: const InputDecoration(
                                labelText: '网关 Base URL',
                                hintText: 'https://example.com',
                                prefixIcon: Icon(Icons.link_rounded),
                              ),
                              validator: (value) {
                                if (_mode != BackendMode.gateway) return null;
                                final uri = Uri.tryParse(value?.trim() ?? '');
                                if (uri == null ||
                                    !uri.hasScheme ||
                                    !uri.hasAuthority ||
                                    (uri.scheme != 'http' &&
                                        uri.scheme != 'https')) {
                                  return '请输入完整的 http:// 或 https:// 地址';
                                }
                                return null;
                              },
                            )
                          : Container(
                              key: const ValueKey('native-info'),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colors.outlineVariant,
                                ),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.security_rounded),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'NovelAI Token 将在设置页单独填写，并保存在系统 Keychain / Keystore 中。',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: _saving ? null : _continue,
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
