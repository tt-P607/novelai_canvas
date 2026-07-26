import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('抗锯齿笔画导出后只剩纯黑与纯白，边缘没有灰色残留', () async {
    final png = await _renderStroke();
    final decoded = img.decodePng(png)!;

    final values = <int>{};
    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        final pixel = decoded.getPixel(x, y);
        values
          ..add(pixel.r.toInt())
          ..add(pixel.g.toInt())
          ..add(pixel.b.toInt());
        expect(pixel.a.toInt(), 255, reason: '蒙版必须完全不透明，否则上游会把边缘当成半重绘区域。');
      }
    }

    expect(
      values.difference({0, 255}),
      isEmpty,
      reason: '出现灰度值说明抗锯齿边缘没有被二值化：$values',
    );
  });
}

/// Reproduces the editor's export path: opaque black backdrop, one anti-aliased
/// white stroke, then the threshold pass.
Future<Uint8List> _renderStroke() async {
  const size = 64;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    Paint()..color = Colors.black,
  );
  canvas.drawPath(
    Path()
      ..moveTo(12, 12)
      ..quadraticBezierTo(32, 40, 52, 20),
    Paint()
      ..color = Colors.white
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..blendMode = BlendMode.srcOver
      ..style = PaintingStyle.stroke,
  );
  final image = await recorder.endRecording().toImage(size, size);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final decoded = img.decodePng(byteData!.buffer.asUint8List())!;

  final mask = img.Image(
    width: decoded.width,
    height: decoded.height,
    numChannels: 3,
  );
  for (var y = 0; y < decoded.height; y++) {
    for (var x = 0; x < decoded.width; x++) {
      final value = decoded.getPixel(x, y).r >= 128 ? 255 : 0;
      mask.setPixelRgb(x, y, value, value, value);
    }
  }
  return img.encodePng(mask);
}
