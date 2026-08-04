import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/entities/pixiv_upload_task.dart';
import '../controllers/pixiv_upload_controller.dart';

class PixivQueuePage extends StatefulWidget {
  const PixivQueuePage({super.key, required this.controller});

  final PixivUploadController controller;

  @override
  State<PixivQueuePage> createState() => _PixivQueuePageState();
}

class _PixivQueuePageState extends State<PixivQueuePage> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final tasks = widget.controller.tasks;
        final isPaused = widget.controller.isPaused;
        return Scaffold(
          backgroundColor: const Color(0xFF0E0C15),
          appBar: AppBar(
            title: const Text('上传队列'),
            actions: [
              IconButton(
                onPressed: () => isPaused
                    ? widget.controller.resume()
                    : widget.controller.pause(),
                icon: Icon(
                  isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                ),
                tooltip: isPaused ? '继续' : '暂停',
              ),
              IconButton(
                onPressed: widget.controller.clearFinished,
                icon: const Icon(Icons.cleaning_services_rounded),
                tooltip: '清空已完成',
              ),
            ],
          ),
          body: tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.queue_outlined, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        '队列为空',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tasks.length,
                  itemBuilder: (context, i) {
                    final task = tasks[i];
                    return _TaskCard(
                      task: task,
                      cooldown: task.cooldownUntil?.difference(DateTime.now()),
                      onCancel: () => widget.controller.cancel(task.id),
                      onRemove: () => widget.controller.remove(task.id),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.cooldown,
    required this.onCancel,
    required this.onRemove,
  });

  final PixivUploadTask task;
  final Duration? cooldown;
  final VoidCallback onCancel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: task.imagePaths.isNotEmpty
                  ? Image.file(
                      File(task.imagePaths.first),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    )
                  : const SizedBox(width: 56, height: 56),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  _statusBadge(context, task.status),
                  if (cooldown != null && cooldown!.inSeconds > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '冷却 ${cooldown!.inMinutes}:${(cooldown!.inSeconds % 60).toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  if (task.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        task.error!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: task.status == PixivUploadStatus.pending
                  ? onCancel
                  : onRemove,
              icon: Icon(
                task.status == PixivUploadStatus.pending
                    ? Icons.cancel_outlined
                    : Icons.delete_outline_rounded,
              ),
              tooltip: task.status == PixivUploadStatus.pending ? '取消' : '移除',
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(BuildContext context, PixivUploadStatus status) {
    final (label, color) = switch (status) {
      PixivUploadStatus.pending => ('等待中', Colors.grey),
      PixivUploadStatus.uploading => ('上传中', Colors.blue),
      PixivUploadStatus.cooldown => ('冷却中', Colors.orange),
      PixivUploadStatus.completed => ('已完成', Colors.green),
      PixivUploadStatus.failed => ('失败', Colors.red),
      PixivUploadStatus.canceled => ('已取消', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color)),
    );
  }
}
