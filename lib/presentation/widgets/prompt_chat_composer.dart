import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'fullscreen_image_preview.dart';
import 'glass/liquid_glass.dart';

/// Input row of the assistant, including the optional pending image preview.
class PromptChatComposer extends StatelessWidget {
  const PromptChatComposer({
    super.key,
    required this.input,
    required this.isRunning,
    required this.pendingImagePath,
    required this.onPickImage,
    required this.onClearImage,
    required this.onSend,
    required this.onCancel,
  });

  final TextEditingController input;
  final bool isRunning;
  final String? pendingImagePath;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final imagePath = pendingImagePath;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassSpec.thinBlurSigma,
          sigmaY: GlassSpec.thinBlurSigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: GlassSpec.body(Theme.of(context).colorScheme),
            border: Border(
              top: BorderSide(
                color: GlassSpec.rimTop(Theme.of(context).colorScheme),
              ),
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: GlassSpec.sheen()),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                children: [
                  if (imagePath != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _attachmentPreview(context, imagePath),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: '添加图片',
                        onPressed: onPickImage,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                      ),
                      Expanded(
                        child: TextField(
                          controller: input,
                          minLines: 1,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            hintText: '询问画面、tag，或要求整理 NovelAI 提示词…',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => onSend(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: isRunning ? '中止请求' : '发送',
                        onPressed: isRunning ? onCancel : onSend,
                        icon: Icon(
                          isRunning
                              ? Icons.stop_rounded
                              : Icons.arrow_upward_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _attachmentPreview(BuildContext context, String path) => Stack(
    children: [
      InkWell(
        onTap: () => FullscreenImagePreview.showFile(context, path),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(path),
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
          onPressed: onClearImage,
          icon: const Icon(Icons.close_rounded, size: 18),
        ),
      ),
    ],
  );
}
