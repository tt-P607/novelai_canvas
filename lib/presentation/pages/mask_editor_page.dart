import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/storage/image_size_reader.dart';
import '../../core/storage/mask_binarizer.dart';
import '../widgets/fullscreen_image_preview.dart';

/// Block-brush mask editor matching NovelAI's official web painter.
///
/// The selection lives on the 8x8 VAE block grid from the start: the brush is
/// a circle quantised to whole blocks, so the on-screen overlay (blocky blue
/// tint with stepped edges) is exactly what gets sent to the API. No
/// anti-aliasing, no binarisation surprises, and the preview never lies.
class MaskEditorPage extends StatefulWidget {
  const MaskEditorPage({super.key, required this.sourceImagePath});

  final String sourceImagePath;

  @override
  State<MaskEditorPage> createState() => _MaskEditorPageState();
}

class _MaskEditorPageState extends State<MaskEditorPage> {
  (int, int)? _sourceSize;
  int _blocksX = 0;
  int _blocksY = 0;

  /// Row-major block selection; true = inpaint.
  List<bool> _blocks = const [];
  final List<List<bool>> _undoStack = [];

  /// Brush diameter in blocks, like the official "Pen Size".
  double _penSize = 18;
  bool _eraser = false;
  bool _saving = false;

  /// Cursor position in block coordinates while painting, for the brush ring.
  Offset? _cursor;

  @override
  void initState() {
    super.initState();
    _loadSourceSize();
  }

  /// The mask must match the source image pixel-for-pixel; the block grid is
  /// derived from the real image size so blocks line up with the VAE latents.
  Future<void> _loadSourceSize() async {
    final size = await readImageSize(widget.sourceImagePath);
    if (!mounted || size == null) return;
    setState(() {
      _sourceSize = size;
      _blocksX = math.max(1, size.$1 ~/ 8);
      _blocksY = math.max(1, size.$2 ~/ 8);
      _blocks = List<bool>.filled(_blocksX * _blocksY, false);
    });
  }

  bool get _hasSelection => _blocks.contains(true);

  @override
  Widget build(BuildContext context) {
    final size = _sourceSize;
    if (size == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('绘制重绘区域')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('绘制重绘区域'),
        actions: [
          IconButton(
            tooltip: '撤销',
            onPressed: _undoStack.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: '清空',
            onPressed: !_hasSelection
                ? null
                : () => setState(() {
                    _pushUndo();
                    _blocks = List<bool>.filled(_blocksX * _blocksY, false);
                  }),
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          TextButton(
            onPressed: _saving || !_hasSelection ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('完成'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: size.$1 / size.$2,
                child: LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    onPanStart: (details) {
                      _pushUndo();
                      _paintAt(details.localPosition, constraints.biggest);
                    },
                    onPanUpdate: (details) =>
                        _paintAt(details.localPosition, constraints.biggest),
                    onPanEnd: (_) => setState(() => _cursor = null),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        GestureDetector(
                          onDoubleTap: () => FullscreenImagePreview.showFile(
                            context,
                            widget.sourceImagePath,
                          ),
                          // The AspectRatio above matches the source, so
                          // image pixels and block coordinates share one grid.
                          child: Image.file(
                            File(widget.sourceImagePath),
                            fit: BoxFit.fill,
                          ),
                        ),
                        RepaintBoundary(
                          child: CustomPaint(
                            painter: _BlockMaskPainter(
                              blocks: _blocks,
                              blocksX: _blocksX,
                              blocksY: _blocksY,
                              cursor: _cursor,
                              penSize: _penSize,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: _eraser ? '切换画笔' : '切换橡皮',
                    onPressed: () => setState(() => _eraser = !_eraser),
                    icon: Icon(
                      _eraser
                          ? Icons.brush_rounded
                          : Icons.auto_fix_normal_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('笔刷'),
                  Expanded(
                    child: Slider(
                      value: _penSize,
                      min: 2,
                      max: 64,
                      onChanged: (value) => setState(() => _penSize = value),
                    ),
                  ),
                  Text(_penSize.round().toString()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pushUndo() {
    _undoStack.add(List<bool>.of(_blocks));
    if (_undoStack.length > 50) _undoStack.removeAt(0);
  }

  void _undo() => setState(() => _blocks = _undoStack.removeLast());

  /// Stamps a circular brush of [_penSize] blocks onto the block grid.
  void _paintAt(Offset local, Size canvasSize) {
    final bx = local.dx / canvasSize.width * _blocksX;
    final by = local.dy / canvasSize.height * _blocksY;
    final radius = _penSize / 2;
    final radiusSq = radius * radius;
    final minX = math.max(0, (bx - radius).floor());
    final maxX = math.min(_blocksX - 1, (bx + radius).ceil());
    final minY = math.max(0, (by - radius).floor());
    final maxY = math.min(_blocksY - 1, (by + radius).ceil());
    setState(() {
      _cursor = Offset(bx, by);
      for (var y = minY; y <= maxY; y++) {
        for (var x = minX; x <= maxX; x++) {
          final dx = x + 0.5 - bx;
          final dy = y + 0.5 - by;
          if (dx * dx + dy * dy <= radiusSq) {
            _blocks[y * _blocksX + x] = !_eraser;
          }
        }
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final source = _sourceSize!;
      final maskBytes = await compute(renderBlockMaskPng, <String, Object>{
        'width': source.$1,
        'height': source.$2,
        'blocksX': _blocksX,
        'blocksY': _blocksY,
        'blocks': _blocks,
      });
      final directory = await getApplicationSupportDirectory();
      final maskDirectory = Directory(p.join(directory.path, 'masks'));
      await maskDirectory.create(recursive: true);
      final path = p.join(
        maskDirectory.path,
        'mask_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await File(path).writeAsBytes(maskBytes, flush: true);
      if (!mounted) return;
      Navigator.pop(context, path);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Draws the selection as translucent blue blocks with a stepped outline plus
/// the circular brush ring, mimicking the official painter's look.
class _BlockMaskPainter extends CustomPainter {
  const _BlockMaskPainter({
    required this.blocks,
    required this.blocksX,
    required this.blocksY,
    required this.cursor,
    required this.penSize,
  });

  final List<bool> blocks;
  final int blocksX;
  final int blocksY;
  final Offset? cursor;
  final double penSize;

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / blocksX;
    final cellH = size.height / blocksY;
    final fill = Paint()..color = const Color(0x594F6BD8);
    final edge = Paint()
      ..color = const Color(0xCC6E8AF0)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    bool on(int x, int y) =>
        x >= 0 &&
        x < blocksX &&
        y >= 0 &&
        y < blocksY &&
        blocks[y * blocksX + x];

    for (var y = 0; y < blocksY; y++) {
      for (var x = 0; x < blocksX; x++) {
        if (!on(x, y)) continue;
        final rect = Rect.fromLTWH(x * cellW, y * cellH, cellW, cellH);
        canvas.drawRect(rect, fill);
        // Stepped outline: draw the edge only where the neighbour is off.
        if (!on(x, y - 1)) {
          canvas.drawLine(rect.topLeft, rect.topRight, edge);
        }
        if (!on(x, y + 1)) {
          canvas.drawLine(rect.bottomLeft, rect.bottomRight, edge);
        }
        if (!on(x - 1, y)) {
          canvas.drawLine(rect.topLeft, rect.bottomLeft, edge);
        }
        if (!on(x + 1, y)) {
          canvas.drawLine(rect.topRight, rect.bottomRight, edge);
        }
      }
    }

    final cursorPosition = cursor;
    if (cursorPosition != null) {
      final ring = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(
        Offset(cursorPosition.dx * cellW, cursorPosition.dy * cellH),
        penSize / 2 * cellW,
        ring,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BlockMaskPainter oldDelegate) =>
      oldDelegate.blocks != blocks ||
      oldDelegate.cursor != cursor ||
      oldDelegate.penSize != penSize;
}
