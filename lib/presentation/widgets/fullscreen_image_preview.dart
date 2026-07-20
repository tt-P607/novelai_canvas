import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class FullscreenImagePreview extends StatelessWidget {
  const FullscreenImagePreview.file({
    super.key,
    required String path,
    this.heroTag,
  }) : _path = path,
       _bytes = null;

  const FullscreenImagePreview.memory({
    super.key,
    required Uint8List bytes,
    this.heroTag,
  }) : _bytes = bytes,
       _path = null;

  final String? _path;
  final Uint8List? _bytes;
  final Object? heroTag;

  static Future<void> showFile(
    BuildContext context,
    String path, {
    Object? heroTag,
  }) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => FullscreenImagePreview.file(path: path, heroTag: heroTag),
    ),
  );

  static Future<void> showMemory(
    BuildContext context,
    Uint8List bytes, {
    Object? heroTag,
  }) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          FullscreenImagePreview.memory(bytes: bytes, heroTag: heroTag),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    Widget image = bytes != null
        ? Image.memory(bytes, fit: BoxFit.contain)
        : Image.file(File(_path!), fit: BoxFit.contain);
    final tag = heroTag;
    if (tag != null) image = Hero(tag: tag, child: image);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: InteractiveViewer(
          minScale: 0.7,
          maxScale: 6,
          boundaryMargin: const EdgeInsets.all(120),
          child: Center(child: image),
        ),
      ),
    );
  }
}
