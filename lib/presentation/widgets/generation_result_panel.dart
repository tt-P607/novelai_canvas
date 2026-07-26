import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'fullscreen_image_preview.dart';
import 'glass/liquid_glass.dart';

/// Shows the streaming preview while a task runs and the stored image once it
/// completes. Both states open a zoomable fullscreen preview on tap.
class GenerationResultPanel extends StatelessWidget {
  const GenerationResultPanel({
    super.key,
    required this.previewBytes,
    required this.previewStep,
    required this.completedImagePath,
    this.onSendToImageTools,
  });

  final List<int>? previewBytes;
  final int? previewStep;
  final String? completedImagePath;
  final ValueChanged<String>? onSendToImageTools;

  @override
  Widget build(BuildContext context) {
    final preview = previewBytes;
    final completedPath = completedImagePath;
    final hasCompleted =
        completedPath != null && File(completedPath).existsSync();
    if (preview == null && !hasCompleted) {
      return const _EmptyResultPlaceholder();
    }

    return LiquidGlass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RepaintBoundary(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.center,
                children: [...previousChildren, ?currentChild],
              ),
              child: preview != null
                  ? _previewImage(context, preview)
                  : _completedImage(context, completedPath!),
            ),
          ),
          _caption(context, isPreview: preview != null, path: completedPath),
        ],
      ),
    );
  }

  Widget _previewImage(BuildContext context, List<int> bytes) {
    final data = Uint8List.fromList(bytes);
    return InkWell(
      onTap: () => FullscreenImagePreview.showMemory(context, data),
      child: Image.memory(
        data,
        key: const ValueKey('stream-preview'),
        width: double.infinity,
        height: 280,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
      ),
    );
  }

  Widget _completedImage(BuildContext context, String path) => InkWell(
    onTap: () => FullscreenImagePreview.showFile(context, path),
    child: Image.file(
      File(path),
      key: ValueKey(path),
      width: double.infinity,
      height: 280,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    ),
  );

  Widget _caption(
    BuildContext context, {
    required bool isPreview,
    required String? path,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        Icon(
          isPreview
              ? Icons.motion_photos_on_outlined
              : Icons.check_circle_outline_rounded,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(isPreview ? '流式预览 · Step ${previewStep ?? 0}' : '最新生成结果'),
        ),
        if (!isPreview && path != null && onSendToImageTools != null)
          IconButton(
            tooltip: '发送到图像工具',
            onPressed: () => onSendToImageTools!(path),
            icon: const Icon(Icons.auto_fix_high_outlined),
          ),
      ],
    ),
  );
}

class _EmptyResultPlaceholder extends StatelessWidget {
  const _EmptyResultPlaceholder();

  @override
  Widget build(BuildContext context) => const LiquidGlass(
    tintOpacity: 0.08,
    child: SizedBox(
      height: 156,
      width: double.infinity,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, size: 34),
            SizedBox(height: 8),
            Text('生成结果会显示在这里'),
          ],
        ),
      ),
    ),
  );
}
