import 'package:flutter/material.dart';

class PlaceholderFeaturePage extends StatelessWidget {
  const PlaceholderFeaturePage({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.nextStage,
  });

  final IconData icon;
  final String title;
  final String description;
  final String nextStage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            constraints: const BoxConstraints(minHeight: 360),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.primaryContainer.withValues(alpha: 0.65),
                  colors.surfaceContainerLow,
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 64, color: colors.primary),
                    const SizedBox(height: 22),
                    Text(
                      '基础入口已就绪',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$nextStage 将接入完整业务能力。当前阶段先确保架构、配置和导航可稳定扩展。',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
