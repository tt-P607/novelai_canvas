import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

import '../../core/errors/error_message.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/entities/generation_task.dart';
import '../controllers/generation_controller.dart';
import '../controllers/history_controller.dart';
import '../widgets/anlas_icon.dart';
import '../widgets/compact_snack_bar.dart';
import '../widgets/fullscreen_image_preview.dart';
import '../widgets/history_card.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.controller,
    required this.generationController,
    required this.onReuse,
  });

  final HistoryController controller;
  final GenerationController generationController;
  final VoidCallback onReuse;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => RefreshIndicator(
          onRefresh: widget.controller.load,
          child: CustomScrollView(
            slivers: [
              SliverAppBar.large(
                title: const Text('作品'),
                actions: [
                  IconButton(
                    tooltip: '刷新',
                    onPressed: widget.controller.load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: SearchBar(
                    hintText: '搜索提示词或模型',
                    leading: const Icon(Icons.search_rounded),
                    onSubmitted: (value) =>
                        widget.controller.load(query: value),
                    trailing: [
                      if (widget.controller.query.isNotEmpty)
                        IconButton(
                          onPressed: () => widget.controller.load(query: ''),
                          icon: const Icon(Icons.clear_rounded),
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: SegmentedButton<HistoryCategory>(
                    segments: const [
                      ButtonSegment(
                        value: HistoryCategory.all,
                        label: Text('全部'),
                      ),
                      ButtonSegment(
                        value: HistoryCategory.favorites,
                        label: Text('收藏'),
                      ),
                      ButtonSegment(
                        value: HistoryCategory.generation,
                        label: Text('生成'),
                      ),
                      ButtonSegment(
                        value: HistoryCategory.tool,
                        label: Text('工具'),
                      ),
                    ],
                    selected: {widget.controller.category},
                    onSelectionChanged: (value) =>
                        widget.controller.setCategory(value.first),
                  ),
                ),
              ),
              if (widget.controller.loading && widget.controller.tasks.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (widget.controller.tasks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyHistory(
                    category: widget.controller.category,
                    hasQuery: widget.controller.query.isNotEmpty,
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    12,
                    8,
                    12,
                    AppSpacing.navBarBottom,
                  ),
                  sliver: SliverMasonryGrid.count(
                    crossAxisCount: MediaQuery.sizeOf(context).width >= 700
                        ? 3
                        : 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childCount: widget.controller.tasks.length,
                    itemBuilder: (context, index) {
                      final task = widget.controller.tasks[index];
                      return HistoryCard(
                        task: task,
                        onTap: () => _showDetails(context, task),
                        onFavorite: () =>
                            widget.controller.toggleFavorite(task.id),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails(BuildContext context, GenerationTask task) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        maxChildSize: 0.95,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            if (task.imagePath != null && File(task.imagePath!).existsSync())
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () =>
                    FullscreenImagePreview.showFile(context, task.imagePath!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.file(File(task.imagePath!)),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              task.spec.prompt,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('负向：${task.spec.negativePrompt}'),
            const Divider(height: 28),
            _detail('后端', task.spec.backendMode.name),
            _detail('模式', task.spec.mode.name),
            _detail('模型', task.spec.model),
            _detail('尺寸', task.spec.size),
            _detail('Steps', task.spec.steps.toString()),
            _detail('Scale', task.spec.scale.toString()),
            _detail('Seed', task.spec.seed.toString()),
            _detail('采样器', task.spec.sampler),
            _detail('调度', task.spec.noiseSchedule),
            if (task.anlasCost != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 76, child: Text('Anlas')),
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnlasIcon(size: 12),
                          const SizedBox(width: 4),
                          SelectableText(task.anlasCost.toString()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                await widget.generationController.reuse(task.id);
                if (!context.mounted) return;
                Navigator.pop(context);
                widget.onReuse();
              },
              icon: const Icon(Icons.replay_rounded),
              label: const Text('复用参数并前往创作'),
            ),
            if (task.imagePath != null)
              OutlinedButton.icon(
                onPressed: () => _saveToGallery(context, task.imagePath!),
                icon: const Icon(Icons.save_alt_rounded),
                label: const Text('保存到系统相册'),
              ),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await widget.controller.delete(task.id);
              },
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('删除作品'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 76, child: Text(label)),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );

  Future<void> _saveToGallery(BuildContext context, String path) async {
    try {
      await ImageGallerySaverPlus.saveFile(path);
      if (!context.mounted) return;
      showCompactSnackBar(
        context,
        icon: Icons.check_circle_rounded,
        message: '已保存到系统相册',
      );
    } catch (error) {
      if (!context.mounted) return;
      showCompactSnackBar(
        context,
        icon: Icons.error_outline_rounded,
        message: '保存失败：${friendlyErrorMessage(error)}',
      );
    }
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.category, required this.hasQuery});

  final HistoryCategory category;
  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, title, message) = switch ((category, hasQuery)) {
      (_, true) => (Icons.search_off_rounded, '没有找到匹配的作品', '换个关键词试试，或清除搜索条件。'),
      (HistoryCategory.favorites, false) => (
        Icons.favorite_border_rounded,
        '还没有收藏',
        '在任意作品卡片右上角点爱心，即可把心仪作品收进这里。',
      ),
      (HistoryCategory.tool, false) => (
        Icons.grid_view_outlined,
        '还没有工具结果',
        '导演工具等处理出的图片会保存在这里。',
      ),
      _ => (Icons.photo_library_outlined, '还没有作品', '生成完成的图片、参数快照和失败任务都会保存在这里。'),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: colors.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
