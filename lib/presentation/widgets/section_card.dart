import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import 'glass/liquid_glass.dart';

/// A frosted panel with an optional header row (icon + title + subtitle + a
/// trailing action), the standard container for grouped settings and tool
/// panels. Replaces hand-built `Card` + `Padding(all: 18)` structures so every
/// grouped surface shares the same glass look.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
  });

  final Widget child;

  /// Header title shown above the body when provided.
  final String? title;

  /// One-line helper text under [title].
  final String? subtitle;

  /// Leading icon tinted with the primary colour.
  final IconData? icon;

  /// Optional widget pinned to the right end of the header row.
  final Widget? trailing;

  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasHeader = title != null;
    return LiquidGlass(
      padding: padding,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHeader) ...[
            if (icon != null || title != null || trailing != null)
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 22, color: colors.primary),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  ?trailing,
                ],
              ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
          child,
        ],
      ),
    );
  }
}
