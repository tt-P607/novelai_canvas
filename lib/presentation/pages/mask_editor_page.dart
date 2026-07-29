import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  /// Cursor position in local pixel coordinates for the magnifier.
  Offset? _cursorPixel;

  /// Canvas render size, captured during layout for the magnifier.
  Size? _canvasSize;

  /// Whether the magnifier loupe is enabled.
  bool _magnifier = true;

  /// GlobalKey for the RepaintBoundary that wraps source image + mask overlay.
  final GlobalKey _boundaryKey = GlobalKey();

  /// Last captured screenshot of the canvas (source image + mask blocks).
  ui.Image? _capturedImage;

  /// Throttle flag so we don't capture more than ~30fps.
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _loadSourceSize();
  }

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

  /// Captures the current canvas (source image + mask overlay) as a ui.Image
  /// for the magnifier. Throttled to avoid excessive captures.
  Future<void> _captureCanvas() async {
    if (_capturing) return;
    _capturing = true;
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null || boundary.size.isEmpty) return;
      // Capture at device pixel ratio for crisp output.
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final image = await boundary.toImage(pixelRatio: dpr);
      if (!mounted) return;
      setState(() => _capturedImage = image);
    } catch (_) {
      // Non-fatal: magnifier just won't update this frame.
    } finally {
      _capturing = false;
    }
  }

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
                  builder: (context, constraints) {
                    _canvasSize = constraints.biggest;
                    return GestureDetector(
                      onPanStart: (details) {
                        _pushUndo();
                        _paintAt(details.localPosition, constraints.biggest);
                      },
                      onPanUpdate: (details) {
                        _paintAt(details.localPosition, constraints.biggest);
                        _captureCanvas();
                      },
                      onPanEnd: (_) => setState(() {
                        _cursor = null;
                        _cursorPixel = null;
                      }),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Wrap source image + mask overlay in a single
                          // RepaintBoundary so we can capture the combined
                          // rendering for the magnifier.
                          RepaintBoundary(
                            key: _boundaryKey,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                GestureDetector(
                                  onDoubleTap: () =>
                                      FullscreenImagePreview.showFile(
                                        context,
                                        widget.sourceImagePath,
                                      ),
                                  child: Image.file(
                                    File(widget.sourceImagePath),
                                    fit: BoxFit.fill,
                                  ),
                                ),
                                CustomPaint(
                                  painter: _BlockMaskPainter(
                                    blocks: _blocks,
                                    blocksX: _blocksX,
                                    blocksY: _blocksY,
                                    cursor: _cursor,
                                    penSize: _penSize,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_magnifier &&
                              _cursorPixel != null &&
                              _capturedImage != null &&
                              _canvasSize != null)
                            _Magnifier(
                              image: _capturedImage!,
                              position: _cursorPixel!,
                              canvasSize: _canvasSize!,
                            ),
                        ],
                      ),
                    );
                  },
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
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: _magnifier ? '关闭放大镜' : '开启放大镜',
                    onPressed: () => setState(() => _magnifier = !_magnifier),
                    icon: Icon(
                      _magnifier
                          ? Icons.zoom_in_rounded
                          : Icons.zoom_out_rounded,
                    ),
                  ),
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
      _cursorPixel = local;
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

/// A circular magnifier that shows a zoomed-in screenshot of the canvas
/// (source image + mask overlay) at the finger position.
///
/// Uses [RepaintBoundary.toImage] to capture the actual rendered pixels, so
/// the magnified content is pixel-perfect aligned with what the user sees —
/// no coordinate math, no re-drawing, just a crop and scale of the real
/// thing.
class _Magnifier extends StatelessWidget {
  const _Magnifier({
    required this.image,
    required this.position,
    required this.canvasSize,
  });

  /// The captured screenshot of the canvas (source image + mask overlay).
  final ui.Image image;

  /// Finger position in canvas (local) coordinates.
  final Offset position;

  /// The render size of the canvas (the AspectRatio child).
  final Size canvasSize;

  static const double _diameter = 120;
  static const double _zoom = 2.5;
  static const double _offsetAbove = 80;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // Position the loupe above the finger, clamped within the canvas.
    final dx = (position.dx - _diameter / 2).clamp(
      0.0,
      (canvasSize.width - _diameter).clamp(0.0, double.infinity),
    );
    var dy = position.dy - _diameter - _offsetAbove;
    if (dy < 0) dy = position.dy + _offsetAbove;

    // The screenshot was captured at device pixel ratio, so its pixel
    // dimensions may differ from the logical canvas size. We need to map
    // from canvas logical coords to screenshot pixel coords.
    final scaleX = image.width / canvasSize.width;
    final scaleY = image.height / canvasSize.height;

    // Crop region in screenshot pixel coordinates, centered on finger.
    final cropW = _diameter / _zoom * scaleX;
    final cropH = _diameter / _zoom * scaleY;
    final cropX = (position.dx * scaleX - cropW / 2).clamp(
      0.0,
      (image.width - cropW).clamp(0.0, double.infinity),
    );
    final cropY = (position.dy * scaleY - cropH / 2).clamp(
      0.0,
      (image.height - cropH).clamp(0.0, double.infinity),
    );

    return Positioned(
      left: dx,
      top: dy,
      child: IgnorePointer(
        child: Container(
          width: _diameter,
          height: _diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.onSurface.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: CustomPaint(
              painter: _MagnifierPainter(
                image: image,
                srcRect: Rect.fromLTWH(cropX, cropY, cropW, cropH),
                dstSize: _diameter,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MagnifierPainter extends CustomPainter {
  const _MagnifierPainter({
    required this.image,
    required this.srcRect,
    required this.dstSize,
  });

  final ui.Image image;
  final Rect srcRect;
  final double dstSize;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the zoomed crop of the screenshot into the full circle.
    canvas.drawImageRect(
      image,
      srcRect,
      Rect.fromLTWH(0, 0, dstSize, dstSize),
      Paint(),
    );

    // Crosshair at center so user knows where the finger is.
    final center = Offset(dstSize / 2, dstSize / 2);
    final crossPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx - 8, center.dy),
      Offset(center.dx + 8, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 8),
      Offset(center.dx, center.dy + 8),
      crossPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MagnifierPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.srcRect != srcRect;
}
