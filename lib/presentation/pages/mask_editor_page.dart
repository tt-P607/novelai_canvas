import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../widgets/fullscreen_image_preview.dart';

class MaskEditorPage extends StatefulWidget {
  const MaskEditorPage({
    super.key,
    required this.sourceImagePath,
    required this.outputWidth,
    required this.outputHeight,
  });

  final String sourceImagePath;
  final int outputWidth;
  final int outputHeight;

  @override
  State<MaskEditorPage> createState() => _MaskEditorPageState();
}

class _MaskEditorPageState extends State<MaskEditorPage> {
  final List<_MaskStroke> _strokes = [];
  _MaskStroke? _activeStroke;
  double _brushSize = 44;
  bool _eraser = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('绘制重绘区域'),
        actions: [
          IconButton(
            tooltip: '撤销',
            onPressed: _strokes.isEmpty
                ? null
                : () => setState(() => _strokes.removeLast()),
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: '清空',
            onPressed: _strokes.isEmpty ? null : () => setState(_strokes.clear),
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          TextButton(
            onPressed: _saving ? null : _save,
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
                aspectRatio: widget.outputWidth / widget.outputHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    onPanStart: (details) => _startStroke(
                      _normalize(details.localPosition, constraints.biggest),
                    ),
                    onPanUpdate: (details) => _appendPoint(
                      _normalize(details.localPosition, constraints.biggest),
                    ),
                    onPanEnd: (_) => _endStroke(),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        GestureDetector(
                          onDoubleTap: () => FullscreenImagePreview.showFile(
                            context,
                            widget.sourceImagePath,
                          ),
                          child: Image.file(
                            File(widget.sourceImagePath),
                            fit: BoxFit.fill,
                          ),
                        ),
                        CustomPaint(
                          painter: _MaskOverlayPainter(
                            strokes: _strokes,
                            activeStroke: _activeStroke,
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
                      value: _brushSize,
                      min: 8,
                      max: 96,
                      onChanged: (value) => setState(() => _brushSize = value),
                    ),
                  ),
                  Text(_brushSize.round().toString()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Offset _normalize(Offset point, Size size) => Offset(
    (point.dx / size.width).clamp(0, 1),
    (point.dy / size.height).clamp(0, 1),
  );

  void _startStroke(Offset point) {
    setState(() {
      _activeStroke = _MaskStroke(
        points: [point],
        normalizedWidth: _brushSize / 400,
        eraser: _eraser,
      );
    });
  }

  void _appendPoint(Offset point) {
    setState(() => _activeStroke?.points.add(point));
  }

  void _endStroke() {
    final stroke = _activeStroke;
    if (stroke == null) return;
    setState(() {
      _strokes.add(stroke);
      _activeStroke = null;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final width = _align8(widget.outputWidth);
      final height = _align8(widget.outputHeight);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Paint()..color = Colors.black,
      );
      for (final stroke in _strokes) {
        _drawStroke(canvas, Size(width.toDouble(), height.toDouble()), stroke);
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw StateError('无法编码蒙版 PNG。');
      final decoded = img.decodePng(byteData.buffer.asUint8List());
      if (decoded == null) throw StateError('无法处理蒙版 PNG。');
      for (final pixel in decoded) {
        final value = pixel.r > 127 ? 255 : 0;
        pixel
          ..r = value
          ..g = value
          ..b = value
          ..a = 255;
      }
      final maskBytes = img.encodePng(decoded);
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

  void _drawStroke(Canvas canvas, Size size, _MaskStroke stroke) {
    if (stroke.points.isEmpty) return;
    final paint = Paint()
      ..color = stroke.eraser ? Colors.black : Colors.white
      ..strokeWidth = stroke.normalizedWidth * size.shortestSide
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..blendMode = BlendMode.src
      ..style = PaintingStyle.stroke;
    canvas.drawPath(_maskSmoothPath(stroke.points, size), paint);
  }

  int _align8(int value) => ((value + 7) ~/ 8) * 8;
}

class _MaskOverlayPainter extends CustomPainter {
  const _MaskOverlayPainter({
    required this.strokes,
    required this.activeStroke,
  });

  final List<_MaskStroke> strokes;
  final _MaskStroke? activeStroke;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final stroke in [...strokes, ?activeStroke]) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.eraser
            ? Colors.transparent
            : const Color(0xFFFF4F9A).withValues(alpha: 0.42)
        ..strokeWidth = stroke.normalizedWidth * size.shortestSide
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..blendMode = stroke.eraser ? BlendMode.clear : BlendMode.srcOver
        ..style = PaintingStyle.stroke;
      canvas.drawPath(_maskSmoothPath(stroke.points, size), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MaskOverlayPainter oldDelegate) => true;
}

class _MaskStroke {
  const _MaskStroke({
    required this.points,
    required this.normalizedWidth,
    required this.eraser,
  });

  final List<Offset> points;
  final double normalizedWidth;
  final bool eraser;
}

Path _maskSmoothPath(List<Offset> points, Size size) {
  final path = Path();
  final first = Offset(
    points.first.dx * size.width,
    points.first.dy * size.height,
  );
  path.moveTo(first.dx, first.dy);
  if (points.length == 1) {
    path.lineTo(first.dx + 0.01, first.dy + 0.01);
    return path;
  }
  for (var index = 1; index < points.length - 1; index++) {
    final current = Offset(
      points[index].dx * size.width,
      points[index].dy * size.height,
    );
    final next = Offset(
      points[index + 1].dx * size.width,
      points[index + 1].dy * size.height,
    );
    final midpoint = Offset(
      (current.dx + next.dx) / 2,
      (current.dy + next.dy) / 2,
    );
    path.quadraticBezierTo(current.dx, current.dy, midpoint.dx, midpoint.dy);
  }
  final last = Offset(
    points.last.dx * size.width,
    points.last.dy * size.height,
  );
  path.lineTo(last.dx, last.dy);
  return path;
}
