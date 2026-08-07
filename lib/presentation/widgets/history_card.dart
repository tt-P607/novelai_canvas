import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/entities/generation_task.dart';
import 'anlas_icon.dart';
import 'glass/liquid_glass.dart';

/// One gallery tile on the 作品 page. Shows the thumbnail with a floating
/// favourite toggle, then a caption row with the prompt and a metadata line.
class HistoryCard extends StatelessWidget {
  const HistoryCard({
    super.key,
    required this.task,
    required this.onTap,
    required this.onFavorite,
  });

  final GenerationTask task;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final imagePath = task.thumbnailPath ?? task.imagePath;
    return GlassPanel(
      radius: 20,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: task.spec.width / task.spec.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                imagePath != null && File(imagePath).existsSync()
                    ? Image.file(File(imagePath), fit: BoxFit.cover)
                    : ColoredBox(
                        color: colors.surfaceContainerHigh,
                        child: Center(
                          child: Icon(
                            task.status == GenerationTaskStatus.failed
                                ? Icons.error_outline_rounded
                                : Icons.hourglass_empty_rounded,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                // Floating favourite toggle — half-transparent pill so the
                // heart reads on any thumbnail and never covers the art.
                Positioned(
                  top: 8,
                  right: 8,
                  child: _FavoriteButton(
                    favorite: task.favorite,
                    onPressed: onFavorite,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.spec.prompt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                _metadataRow(theme, colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metadataRow(ThemeData theme, ColorScheme colors) => Row(
    children: [
      Expanded(
        child: Text(
          '${_shortModel(task.spec.model)} · ${task.spec.width}×${task.spec.height}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
      if (task.anlasCost != null) ...[
        const SizedBox(width: 6),
        AnlasIcon(size: 11),
        const SizedBox(width: 2),
        Text(
          '${task.anlasCost}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
      const SizedBox(width: 6),
      Text(
        _relativeTime(task.createdAt),
        style: theme.textTheme.labelSmall?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
    ],
  );

  /// Keeps the model label short so the metadata row fits one line.
  String _shortModel(String model) {
    if (model.startsWith('director-')) return '工具';
    if (model.contains('nai-diffusion-4-5')) return 'V4.5';
    if (model.contains('nai-diffusion-4')) return 'V4';
    if (model.contains('nai-diffusion-3')) return 'V3';
    if (model.contains('nai-diffusion-2')) return 'V2';
    return model;
  }

  String _relativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time.toLocal());
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    if (diff.inDays < 30) return '${diff.inDays ~/ 7} 周前';
    if (diff.inDays < 365) return '${diff.inDays ~/ 30} 个月前';
    return '${diff.inDays ~/ 365} 年前';
  }
}

class _FavoriteButton extends StatefulWidget {
  const _FavoriteButton({required this.favorite, required this.onPressed});

  final bool favorite;
  final VoidCallback onPressed;

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton> {
  bool _scaled = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _scaled = true);
        // Heartbeat: scale up then settle back, synced to the fill change.
        Future.delayed(const Duration(milliseconds: 140), () {
          if (mounted) setState(() => _scaled = false);
        });
        widget.onPressed();
      },
      child: AnimatedScale(
        scale: _scaled ? 1.35 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          ),
          child: Icon(
            widget.favorite ? Icons.favorite_rounded : Icons.favorite_border,
            size: 18,
            color: widget.favorite ? Colors.redAccent : Colors.white,
          ),
        ),
      ),
    );
  }
}
