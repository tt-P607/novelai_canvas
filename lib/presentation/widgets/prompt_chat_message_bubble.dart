import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/entities/prompt_assistant.dart';
import 'fullscreen_image_preview.dart';
import 'glass/liquid_glass.dart';

/// Renders one entry of the assistant conversation.
///
/// Notices are centered hints such as "调用了标签搜索"; user and assistant
/// messages use opposing bubbles, and any message carrying a prompt result
/// exposes its own apply button so old replies stay reusable.
class PromptChatMessageBubble extends StatelessWidget {
  const PromptChatMessageBubble({
    super.key,
    required this.message,
    required this.onApply,
    this.onLongPress,
  });

  final PromptChatMessage message;
  final ValueChanged<PromptAssistantResult> onApply;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    if (message.role == PromptChatRole.notice) {
      return _NoticeLine(text: message.content);
    }

    final colors = Theme.of(context).colorScheme;
    final isUser = message.role == PromptChatRole.user;
    final promptResult = message.promptResult;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: isUser ? onLongPress : null,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isUser
                ? colors.primary.withValues(alpha: 0.24)
                : Colors.white.withValues(alpha: 0.07),
            border: Border.all(color: GlassSpec.edge(colors, opacity: 0.16)),
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
                _attachment(context, message.imagePath!),
                if (message.content.isNotEmpty) const SizedBox(height: 10),
              ],
              if (message.content.isNotEmpty) SelectableText(message.content),
              if (promptResult != null) _applySection(context, promptResult),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachment(BuildContext context, String path) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: () => FullscreenImagePreview.showFile(context, path),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(path),
        height: 180,
        width: 240,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const SizedBox(height: 80, child: Center(child: Text('图片文件已不可用'))),
      ),
    ),
  );

  Widget _applySection(BuildContext context, PromptAssistantResult result) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.auto_fix_high_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              const Expanded(child: Text('这条消息包含可复用的提示词结果')),
              FilledButton.tonalIcon(
                onPressed: () => onApply(result),
                icon: const Icon(Icons.input_rounded, size: 18),
                label: const Text('填入'),
              ),
            ],
          ),
        ],
      );
}

class _NoticeLine extends StatelessWidget {
  const _NoticeLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bolt_rounded, size: 14, color: colors.onSurfaceVariant),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
