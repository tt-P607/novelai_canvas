import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/prompt_assistant.dart';
import '../controllers/generation_controller.dart';
import '../controllers/llm_assistant_settings_controller.dart';
import '../controllers/prompt_assistant_controller.dart';
import '../widgets/prompt_chat_composer.dart';
import '../widgets/prompt_chat_message_bubble.dart';

class PromptAssistantPage extends StatefulWidget {
  const PromptAssistantPage({
    super.key,
    required this.controller,
    required this.settingsController,
    required this.generationController,
    this.embedded = false,
    this.onApplied,
  });

  final PromptAssistantController controller;
  final LlmAssistantSettingsController settingsController;
  final GenerationController generationController;
  final bool embedded;
  final VoidCallback? onApplied;

  @override
  State<PromptAssistantPage> createState() => _PromptAssistantPageState();
}

class _PromptAssistantPageState extends State<PromptAssistantPage> {
  final _input = TextEditingController();
  final _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  PromptAssistantController get controller => widget.controller;

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          children: [
            _toolbar(),
            Expanded(child: _conversation()),
            if (controller.errorMessage != null) _errorNotice(),
            PromptChatComposer(
              input: _input,
              isRunning: controller.isRunning,
              pendingImagePath: controller.pendingImagePath,
              onPickImage: _pickImage,
              onClearImage: () => controller.setPendingImage(null),
              onSend: _send,
              onCancel: controller.cancel,
            ),
          ],
        ),
      ),
    );
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('提示词助手')),
      body: content,
    );
  }

  Widget _conversation() {
    if (controller.messages.isEmpty && !controller.isRunning) {
      return const _EmptyState();
    }
    final messageCount = controller.messages.length;
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      itemCount: messageCount + (controller.isRunning ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messageCount) return _modelActivity();
        final message = controller.messages[index];
        return PromptChatMessageBubble(
          message: message,
          onApply: (result) => _apply(result, close: false),
          onLongPress: () => _showMessageActions(message),
        );
      },
    );
  }

  Widget _toolbar() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 8, 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            controller.activeSession.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: '会话历史',
          onPressed: _showHistory,
          icon: const Icon(Icons.history_rounded),
        ),
        IconButton(
          tooltip: '归档当前会话',
          onPressed: controller.archiveActiveSession,
          icon: const Icon(Icons.archive_outlined),
        ),
        IconButton(
          tooltip: '新对话',
          onPressed: controller.newSession,
          icon: const Icon(Icons.add_comment_outlined),
        ),
      ],
    ),
  );

  Widget _errorNotice() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
      child: Material(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
          child: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: colors.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  controller.errorMessage!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (controller.failedMessage != null)
                TextButton(
                  onPressed: _retryLastFailure,
                  child: const Text('重试'),
                ),
              IconButton(
                tooltip: '关闭',
                visualDensity: VisualDensity.compact,
                onPressed: controller.clearError,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modelActivity() {
    final colors = Theme.of(context).colorScheme;
    final status = controller.operationStatus ?? '正在响应…';
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              status.contains('思考') ? '模型正在思考' : status,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: '中止请求',
              visualDensity: VisualDensity.compact,
              onPressed: controller.cancel,
              icon: const Icon(Icons.stop_circle_outlined, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) controller.setPendingImage(image.path);
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty && controller.pendingImagePath == null) return;
    _input.clear();
    await controller.send(
      text: text,
      currentPositive: widget.generationController.prompt,
      currentNegative: widget.generationController.negativePrompt,
    );
    _afterReply();
  }

  Future<void> _retryMessage(PromptChatMessage message) async {
    await controller.retryMessage(
      message: message,
      currentPositive: widget.generationController.prompt,
      currentNegative: widget.generationController.negativePrompt,
    );
    _afterReply();
  }

  Future<void> _retryLastFailure() async {
    await controller.retryLastFailure(
      currentPositive: widget.generationController.prompt,
      currentNegative: widget.generationController.negativePrompt,
    );
    _afterReply();
  }

  /// Applies the fresh result when auto-apply is enabled and keeps the newest
  /// message visible. Shared by the initial send and both retry paths.
  void _afterReply() {
    if (!mounted) return;
    final result = controller.latestPromptResult;
    if (result != null && widget.settingsController.settings.autoApplyPrompt) {
      _apply(result, close: false);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _showMessageActions(PromptChatMessage message) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.refresh_rounded),
          title: const Text('重新发送'),
          subtitle: const Text('使用当前创作页提示词作为上下文再次请求'),
          onTap: () {
            Navigator.pop(sheetContext);
            _retryMessage(message);
          },
        ),
      ),
    );
  }

  void _apply(PromptAssistantResult result, {bool close = true}) {
    widget.generationController.applyAssistantResult(result);
    widget.onApplied?.call();
    if (close && widget.onApplied == null && !widget.embedded) {
      Navigator.of(context).pop();
    }
  }

  void _showHistory() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Text('对话历史', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...controller.sessions.map(
              (session) => _sessionTile(session, sheetContext),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionTile(PromptChatSession session, BuildContext sheetContext) =>
      ListTile(
        leading: Icon(
          session.archived
              ? Icons.archive_rounded
              : Icons.chat_bubble_outline_rounded,
        ),
        title: Text(session.title),
        subtitle: Text(
          '${session.messages.length} 条消息 · '
          '${session.updatedAt.toLocal().toString().substring(0, 16)}',
        ),
        selected: session.id == controller.activeSessionId,
        trailing: session.archived
            ? IconButton(
                tooltip: '取消归档',
                onPressed: () => controller.unarchiveSession(session.id),
                icon: const Icon(Icons.unarchive_outlined),
              )
            : null,
        onTap: () {
          controller.selectSession(session.id);
          Navigator.pop(sheetContext);
        },
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text('直接和助手讨论画面', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            '你可以问角色 tag、构图、光影，也可以附图询问“这个服装是什么 tag”。'
            '当需要校准标签时，助手会自己调用 Danbooru 工具。',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
