import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
  double _brushSize = 36;
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
                        Image.file(
                          File(widget.sourceImagePath),
                          fit: BoxFit.fill,
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
      final directory = await getApplicationSupportDirectory();
      final maskDirectory = Directory(p.join(directory.path, 'masks'));
      await maskDirectory.create(recursive: true);
      final path = p.join(
        maskDirectory.path,
        'mask_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await File(path).writeAsBytes(byteData.buffer.asUint8List(), flush: true);
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
      ..style = PaintingStyle.stroke;
    final path = Path();
    final first = _denormalize(stroke.points.first, size);
    path.moveTo(first.dx, first.dy);
    if (stroke.points.length == 1) {
      path.lineTo(first.dx + 0.01, first.dy + 0.01);
    } else {
      for (final point in stroke.points.skip(1)) {
        final position = _denormalize(point, size);
        path.lineTo(position.dx, position.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  Offset _denormalize(Offset point, Size size) =>
      Offset(point.dx * size.width, point.dy * size.height);

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
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );
    for (final stroke in [...strokes, ?activeStroke]) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        // 使用不透明预览色，避免分多笔涂抹时透明度叠加造成“重叠变深”。
        ..color = stroke.eraser
            ? const Color(0xFF19171F)
            : const Color(0xFFE45C68)
        ..strokeWidth = stroke.normalizedWidth * size.shortestSide
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path();
      final first = _position(stroke.points.first, size);
      path.moveTo(first.dx, first.dy);
      if (stroke.points.length == 1) {
        path.lineTo(first.dx + 0.01, first.dy + 0.01);
      } else {
        for (final point in stroke.points.skip(1)) {
          final position = _position(point, size);
          path.lineTo(position.dx, position.dy);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  Offset _position(Offset point, Size size) =>
      Offset(point.dx * size.width, point.dy * size.height);

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
