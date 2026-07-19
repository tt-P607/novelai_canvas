import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

import '../../domain/entities/generation_task.dart';
import '../controllers/generation_controller.dart';
import '../controllers/history_controller.dart';

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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
              if (widget.controller.loading && widget.controller.tasks.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (widget.controller.tasks.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyHistory(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
                  sliver: SliverMasonryGrid.count(
                    crossAxisCount: MediaQuery.sizeOf(context).width >= 700
                        ? 3
                        : 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childCount: widget.controller.tasks.length,
                    itemBuilder: (context, index) => _HistoryCard(
                      task: widget.controller.tasks[index],
                      onTap: () =>
                          _showDetails(context, widget.controller.tasks[index]),
                      onFavorite: () => widget.controller.toggleFavorite(
                        widget.controller.tasks[index].id,
                      ),
                    ),
                  ),
                ),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(File(task.imagePath!)),
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
              _detail('Anlas', task.anlasCost.toString()),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('图片已保存到系统相册。')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
    }
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.task,
    required this.onTap,
    required this.onFavorite,
  });

  final GenerationTask task;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final imagePath = task.thumbnailPath ?? task.imagePath;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: task.spec.width / task.spec.height,
              child: imagePath != null && File(imagePath).existsSync()
                  ? Image.file(File(imagePath), fit: BoxFit.cover)
                  : ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      child: Center(
                        child: Icon(
                          task.status == GenerationTaskStatus.failed
                              ? Icons.error_outline_rounded
                              : Icons.hourglass_empty_rounded,
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      task.spec.prompt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: onFavorite,
                    icon: Icon(
                      task.favorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text('还没有作品', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('生成完成的图片、参数快照和失败任务都会保存在这里。'),
        ],
      ),
    ),
  );
}
