import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/prompt_assistant.dart';
import '../controllers/generation_controller.dart';
import '../widgets/fullscreen_image_preview.dart';
import '../controllers/llm_assistant_settings_controller.dart';
import '../controllers/prompt_assistant_controller.dart';

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
        listenable: widget.controller,
        builder: (context, _) => Column(
          children: [
            _toolbar(),
            Expanded(
              child:
                  widget.controller.messages.isEmpty &&
                      !widget.controller.isRunning
                  ? _emptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                      itemCount:
                          widget.controller.messages.length +
                          (widget.controller.isRunning ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == widget.controller.messages.length) {
                          return _modelActivity();
                        }
                        return _messageBubble(
                          widget.controller.messages[index],
                        );
                      },
                    ),
            ),
            if (widget.controller.errorMessage != null) _errorNotice(),
            _composer(),
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

  Widget _toolbar() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 8, 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            widget.controller.activeSession.title,
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
          onPressed: widget.controller.archiveActiveSession,
          icon: const Icon(Icons.archive_outlined),
        ),
        IconButton(
          tooltip: '新对话',
          onPressed: widget.controller.newSession,
          icon: const Icon(Icons.add_comment_outlined),
        ),
      ],
    ),
  );

  Widget _errorNotice() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
    child: Material(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.controller.errorMessage!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (widget.controller.failedMessage != null)
              TextButton(onPressed: _retryLastFailure, child: const Text('重试')),
            IconButton(
              tooltip: '关闭',
              visualDensity: VisualDensity.compact,
              onPressed: widget.controller.clearError,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _emptyState() => Center(
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
            '你可以问角色 tag、构图、光影，也可以附图询问“这个服装是什么 tag”。当需要校准标签时，助手会自己调用 Danbooru 工具。',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Widget _messageBubble(PromptChatMessage message) {
    if (message.role == PromptChatRole.notice) {
      return _noticeMessage(message.content);
    }
    final isUser = message.role == PromptChatRole.user;
    final colors = Theme.of(context).colorScheme;
    final promptResult = message.promptResult;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: isUser ? () => _showMessageActions(message) : null,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isUser
                ? colors.primaryContainer
                : colors.surfaceContainerHigh,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.imagePath != null) ...[
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => FullscreenImagePreview.showFile(
                    context,
                    message.imagePath!,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(message.imagePath!),
                      height: 180,
                      width: 240,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 80,
                        child: Center(child: Text('图片文件已不可用')),
                      ),
                    ),
                  ),
                ),
                if (message.content.isNotEmpty) const SizedBox(height: 10),
              ],
              if (message.content.isNotEmpty) SelectableText(message.content),
              if (promptResult != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.auto_fix_high_rounded,
                      size: 18,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(child: Text('这条消息包含可复用的提示词结果')),
                    FilledButton.tonalIcon(
                      onPressed: () => _apply(promptResult, close: false),
                      icon: const Icon(Icons.input_rounded, size: 18),
                      label: const Text('填入'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _noticeMessage(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.bolt_rounded,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _modelActivity() {
    final status = widget.controller.operationStatus ?? '正在响应…';
    final thinking = status.contains('思考');
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
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              thinking ? '模型正在思考' : status,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: '中止请求',
              visualDensity: VisualDensity.compact,
              onPressed: widget.controller.cancel,
              icon: const Icon(Icons.stop_circle_outlined, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    final imagePath = widget.controller.pendingImagePath;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          children: [
            if (imagePath != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Stack(
                  children: [
                    InkWell(
                      onTap: () =>
                          FullscreenImagePreview.showFile(context, imagePath),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(imagePath),
                          width: 96,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            widget.controller.setPendingImage(null),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            if (imagePath != null) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: '添加图片',
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                ),
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: '询问画面、tag，或要求整理 NovelAI 提示词…',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: widget.controller.isRunning ? '中止请求' : '发送',
                  onPressed: widget.controller.isRunning
                      ? widget.controller.cancel
                      : _send,
                  icon: Icon(
                    widget.controller.isRunning
                        ? Icons.stop_rounded
                        : Icons.arrow_upward_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) widget.controller.setPendingImage(image.path);
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty && widget.controller.pendingImagePath == null) {
      return;
    }
    _input.clear();
    await widget.controller.send(
      text: text,
      currentPositive: widget.generationController.prompt,
      currentNegative: widget.generationController.negativePrompt,
    );
    if (!mounted) return;
    final result = widget.controller.latestPromptResult;
    if (result != null && widget.settingsController.settings.autoApplyPrompt) {
      _apply(result, close: false);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _retryMessage(PromptChatMessage message) async {
    await widget.controller.retryMessage(
      message: message,
      currentPositive: widget.generationController.prompt,
      currentNegative: widget.generationController.negativePrompt,
    );
    if (!mounted) return;
    final result = widget.controller.latestPromptResult;
    if (result != null && widget.settingsController.settings.autoApplyPrompt) {
      _apply(result, close: false);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _retryLastFailure() async {
    await widget.controller.retryLastFailure(
      currentPositive: widget.generationController.prompt,
      currentNegative: widget.generationController.negativePrompt,
    );
    if (!mounted) return;
    final result = widget.controller.latestPromptResult;
    if (result != null && widget.settingsController.settings.autoApplyPrompt) {
      _apply(result, close: false);
    }
  }

  void _showMessageActions(PromptChatMessage message) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.refresh_rounded),
          title: const Text('重新发送'),
          subtitle: const Text('使用当前创作页提示词作为上下文再次请求'),
          onTap: () {
            Navigator.pop(context);
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
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Text('对话历史', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...widget.controller.sessions.map(
              (session) => ListTile(
                leading: Icon(
                  session.archived
                      ? Icons.archive_rounded
                      : Icons.chat_bubble_outline_rounded,
                ),
                title: Text(session.title),
                subtitle: Text(
                  '${session.messages.length} 条消息 · ${session.updatedAt.toLocal().toString().substring(0, 16)}',
                ),
                selected: session.id == widget.controller.activeSessionId,
                trailing: session.archived
                    ? IconButton(
                        tooltip: '取消归档',
                        onPressed: () =>
                            widget.controller.unarchiveSession(session.id),
                        icon: const Icon(Icons.unarchive_outlined),
                      )
                    : null,
                onTap: () {
                  widget.controller.selectSession(session.id);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
