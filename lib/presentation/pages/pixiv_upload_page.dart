import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/error_message.dart';
import '../../domain/entities/pixiv_upload_task.dart';
import '../controllers/pixiv_settings_controller.dart';
import '../controllers/pixiv_upload_controller.dart';
import '../widgets/compact_snack_bar.dart';
import 'pixiv_queue_page.dart';
import 'pixiv_settings_page.dart';

class PixivUploadPage extends StatefulWidget {
  const PixivUploadPage({
    super.key,
    required this.uploadController,
    required this.settingsController,
    required this.initialImagePaths,
  });

  final PixivUploadController uploadController;
  final PixivSettingsController settingsController;
  final List<String> initialImagePaths;

  @override
  State<PixivUploadPage> createState() => _PixivUploadPageState();
}

class _PixivUploadPageState extends State<PixivUploadPage> {
  late final TextEditingController _title;
  late final TextEditingController _caption;
  late final TextEditingController _tags;
  late List<String> _images;
  bool _isR18 = false;

  @override
  void initState() {
    super.initState();
    final s = widget.settingsController.settings;
    _title = TextEditingController();
    _caption = TextEditingController(text: s.captionPrefix);
    _tags = TextEditingController(text: s.defaultTags.join(', '));
    _images = List.from(widget.initialImagePaths);
    _isR18 = s.r18Default;
  }

  @override
  void dispose() {
    _title.dispose();
    _caption.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pushed routes are opaque and this app's scaffold background is
    // transparent (the frosted look comes from HomeShell's LiquidGlassBackdrop),
    // so a pushed page must paint its own dark backdrop or the large empty
    // areas show the raw MaterialApp background as a gray sheet.
    return Scaffold(
      backgroundColor: const Color(0xFF0E0C15),
      appBar: AppBar(
        title: const Text('发布到 Pixiv'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    PixivQueuePage(controller: widget.uploadController),
              ),
            ),
            icon: const Icon(Icons.queue_rounded),
            tooltip: '上传队列',
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    PixivSettingsPage(controller: widget.settingsController),
              ),
            ),
            icon: const Icon(Icons.settings_rounded),
            tooltip: '设置',
          ),
        ],
      ),
      body: ListView(
        // This page sits inside the bottom-nav shell (extendBody), so reserve
        // enough room for the floating glass nav bar plus the system inset to
        // keep the submit button visible and tappable.
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.paddingOf(context).bottom + 120,
        ),
        children: [
          if (_images.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.image_outlined, size: 48),
                    const SizedBox(height: 8),
                    Text('未选择图片', style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_images[i]),
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _images.removeAt(i)),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickImages,
            icon: const Icon(Icons.add_photo_alternate_rounded),
            label: const Text('从相册选图'),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: '标题',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _caption,
                    decoration: const InputDecoration(
                      labelText: '正文',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tags,
                    decoration: const InputDecoration(
                      labelText: '标签 (逗号分隔)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('R18'),
                    value: _isR18,
                    onChanged: (v) => setState(() => _isR18 = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.publish_rounded),
            label: const Text('提交到上传队列'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final result = await picker.pickMultiImage(imageQuality: null);
    if (result.isEmpty) return;
    setState(() {
      _images.addAll(result.map((x) => x.path));
    });
  }

  void _submit() {
    if (_images.isEmpty) {
      showCompactSnackBar(
        context,
        icon: Icons.image_not_supported_outlined,
        message: '请先选择图片',
      );
      return;
    }
    if (_title.text.trim().isEmpty) {
      showCompactSnackBar(context, icon: Icons.edit_outlined, message: '请填写标题');
      return;
    }
    final s = widget.settingsController.settings;
    if (!s.hasCredentials) {
      showCompactSnackBar(
        context,
        icon: Icons.key_off_outlined,
        message: '请先在设置中配置 Cookie 和 Token',
      );
      return;
    }
    final tags = _tags.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final task = PixivUploadTask(
      id: const Uuid().v4(),
      imagePaths: List.from(_images),
      title: _title.text.trim(),
      caption: _caption.text.trim(),
      tags: tags,
      isR18: _isR18,
      allowTagEdit: s.allowTagEdit,
      stripMetadata: s.stripMetadata,
      createdAt: DateTime.now(),
    );
    try {
      widget.uploadController.enqueue(task);
      showCompactSnackBar(context, icon: Icons.check_rounded, message: '已加入队列');
      // This page lives in the bottom-nav shell (IndexedStack), not a pushed
      // route, so popping would leave the shell. Reset the form instead so the
      // user can queue another artwork without re-entering the page.
      _title.clear();
      _caption.clear();
      _tags.clear();
      setState(() {
        _images.clear();
        _isR18 = widget.settingsController.settings.r18Default;
      });
    } catch (e) {
      showCompactSnackBar(
        context,
        icon: Icons.error_outline_rounded,
        message: friendlyErrorMessage(e),
      );
    }
  }
}
