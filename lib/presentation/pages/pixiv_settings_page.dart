import 'package:flutter/material.dart';

import '../../core/errors/error_message.dart';
import '../controllers/pixiv_settings_controller.dart';
import '../widgets/compact_snack_bar.dart';
import '../widgets/pixiv_defaults_card.dart';
import 'pixiv_login_page.dart';

class PixivSettingsPage extends StatefulWidget {
  const PixivSettingsPage({super.key, required this.controller});

  final PixivSettingsController controller;

  @override
  State<PixivSettingsPage> createState() => _PixivSettingsPageState();
}

class _PixivSettingsPageState extends State<PixivSettingsPage> {
  late final TextEditingController _cookie;
  late final TextEditingController _csrf;
  late final TextEditingController _proxy;
  late final TextEditingController _captionPrefix;
  late final TextEditingController _tags;
  late final TextEditingController _cooldown;
  late final TextEditingController _junk;

  @override
  void initState() {
    super.initState();
    final s = widget.controller.settings;
    _cookie = TextEditingController(text: s.cookie);
    _csrf = TextEditingController(text: s.csrfToken);
    _proxy = TextEditingController(text: s.proxy);
    _captionPrefix = TextEditingController(text: s.captionPrefix);
    _tags = TextEditingController(text: s.defaultTags.join(', '));
    _cooldown = TextEditingController(text: s.cooldownMinutes.toString());
    _junk = TextEditingController(text: s.junkText);
  }

  @override
  void dispose() {
    _cookie.dispose();
    _csrf.dispose();
    _proxy.dispose();
    _captionPrefix.dispose();
    _tags.dispose();
    _cooldown.dispose();
    _junk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final cur = widget.controller.settings;
        return Scaffold(
          backgroundColor: const Color(0xFF0E0C15),
          appBar: AppBar(title: const Text('Pixiv 设置')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '登录凭据',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _loginWithWebView,
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('一键登录'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _cookie,
                        decoration: const InputDecoration(
                          labelText: 'Cookie',
                          hintText: '从浏览器提取的完整 Cookie',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _csrf,
                        decoration: const InputDecoration(
                          labelText: 'x-csrf-token',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('网络', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _proxy,
                        decoration: const InputDecoration(
                          labelText: '代理 (可选)',
                          hintText: 'http://127.0.0.1:7890',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '发布默认值',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _captionPrefix,
                        decoration: const InputDecoration(
                          labelText: '正文前缀',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _tags,
                        decoration: const InputDecoration(
                          labelText: '默认标签 (逗号分隔)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _cooldown,
                        decoration: const InputDecoration(
                          labelText: '冷却分钟',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              PixivDefaultsCard(
                xRestrict: cur.xRestrictDefault,
                aiType: cur.aiTypeDefault,
                restrict: cur.restrictDefault,
                allowComment: cur.allowCommentDefault,
                original: cur.originalDefault,
                allowTagEdit: cur.allowTagEdit,
                stripMetadata: cur.stripMetadata,
                suggestTagsEnabled: cur.suggestTagsEnabled,
                onXRestrictChanged: (v) =>
                    widget.controller.save(cur.copyWith(xRestrictDefault: v)),
                onAiTypeChanged: (v) =>
                    widget.controller.save(cur.copyWith(aiTypeDefault: v)),
                onRestrictChanged: (v) =>
                    widget.controller.save(cur.copyWith(restrictDefault: v)),
                onAllowCommentChanged: (v) => widget.controller.save(
                  cur.copyWith(allowCommentDefault: v),
                ),
                onOriginalChanged: (v) =>
                    widget.controller.save(cur.copyWith(originalDefault: v)),
                onAllowTagEditChanged: (v) =>
                    widget.controller.save(cur.copyWith(allowTagEdit: v)),
                onStripMetadataChanged: (v) =>
                    widget.controller.save(cur.copyWith(stripMetadata: v)),
                onSuggestTagsChanged: (v) =>
                    widget.controller.save(cur.copyWith(suggestTagsEnabled: v)),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded),
                label: const Text('保存'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await widget.controller.clearCredentials();
                  _cookie.clear();
                  _csrf.clear();
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('清除凭据'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Opens the in-app Pixiv login page; on success fills the Cookie and CSRF
  /// fields so the user never has to copy them from a browser.
  Future<void> _loginWithWebView() async {
    final result = await Navigator.of(context).push<PixivLoginResult>(
      MaterialPageRoute(builder: (_) => const PixivLoginPage()),
    );
    if (!mounted || result == null) return;
    _cookie.text = result.cookie;
    _csrf.text = result.csrfToken;
    setState(() {});
    showCompactSnackBar(
      context,
      icon: Icons.check_rounded,
      message: '登录成功，Cookie 已获取',
    );
  }

  Future<void> _save() async {
    try {
      final tags = _tags.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      final cooldown = int.tryParse(_cooldown.text.trim()) ?? 10;
      await widget.controller.save(
        widget.controller.settings.copyWith(
          cookie: _cookie.text.trim(),
          csrfToken: _csrf.text.trim(),
          proxy: _proxy.text.trim(),
          captionPrefix: _captionPrefix.text.trim(),
          defaultTags: tags,
          cooldownMinutes: cooldown,
          junkText: _junk.text.trim(),
        ),
      );
      if (!mounted) return;
      showCompactSnackBar(context, icon: Icons.check_rounded, message: '已保存');
    } catch (e) {
      if (!mounted) return;
      showCompactSnackBar(
        context,
        icon: Icons.error_outline_rounded,
        message: friendlyErrorMessage(e),
      );
    }
  }
}
