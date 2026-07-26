import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:novelai_canvas/core/storage/mask_binarizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('抗锯齿笔画导出后只剩纯黑与纯白，边缘没有灰色残留', () async {
    final png = binarizeMaskToVaeGrid(await _renderStrokePng());
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

  test('蒙版边缘按 8x8 VAE 块对齐，每个块要么全选要么全不选', () async {
    final png = binarizeMaskToVaeGrid(await _renderStrokePng());
    final decoded = img.decodePng(png)!;

    // Every 8x8 block must be uniform; a mixed block would leave the VAE
    // half-inpainting it, which is the root cause of the grey fringe.
    for (var by = 0; by < decoded.height ~/ 8; by++) {
      for (var bx = 0; bx < decoded.width ~/ 8; bx++) {
        final first = decoded.getPixel(bx * 8, by * 8).r.toInt();
        for (var y = by * 8; y < (by + 1) * 8; y++) {
          for (var x = bx * 8; x < (bx + 1) * 8; x++) {
            expect(
              decoded.getPixel(x, y).r.toInt(),
              first,
              reason: '块 ($bx,$by) 内像素不一致，蒙版没有对齐 VAE 网格',
            );
          }
        }
      }
    }
  });

  test('几乎全白的蒙版对齐后保留重绘区域，几乎全黑的保持为空', () async {
    final whitePng = _solidPng(64, 64, 250);
    final blackPng = _solidPng(64, 64, 5);

    final white = img.decodePng(binarizeMaskToVaeGrid(whitePng))!;
    final black = img.decodePng(binarizeMaskToVaeGrid(blackPng))!;

    expect(white.getPixel(32, 32).r.toInt(), 255);
    expect(black.getPixel(32, 32).r.toInt(), 0);
  });
}

/// Reproduces the editor's raw export: opaque black backdrop plus one
/// anti-aliased white stroke, before any binarisation.
Future<Uint8List> _renderStrokePng() async {
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
  return byteData!.buffer.asUint8List();
}

Uint8List _solidPng(int width, int height, int value) {
  final image = img.Image(width: width, height: height, numChannels: 3);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(x, y, value, value, value);
    }
  }
  return img.encodePng(image);
}
