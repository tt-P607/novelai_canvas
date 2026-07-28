import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:novelai_canvas/core/storage/mask_binarizer.dart';

void main() {
  test('块选择渲染为纯黑白 RGB 蒙版，无灰度残留', () {
    final blocks = List<bool>.filled(8 * 8, false)..[3 * 8 + 4] = true;
    final png = renderBlockMaskPng(<String, Object>{
      'width': 64,
      'height': 64,
      'blocksX': 8,
      'blocksY': 8,
      'blocks': blocks,
    });
    final decoded = img.decodePng(png)!;

    final values = <int>{};
    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        final pixel = decoded.getPixel(x, y);
        values
          ..add(pixel.r.toInt())
          ..add(pixel.g.toInt())
          ..add(pixel.b.toInt());
      }
    }
    expect(
      values.difference({0, 255}),
      isEmpty,
      reason: '出现灰度值说明蒙版没有二值化：$values',
    );
  });

  test('每个 8x8 块要么整块重绘要么整块保留，与 VAE 网格对齐', () {
    final blocks = List<bool>.filled(8 * 8, false)
      ..[0] = true
      ..[3 * 8 + 4] = true
      ..[7 * 8 + 7] = true;
    final png = renderBlockMaskPng(<String, Object>{
      'width': 64,
      'height': 64,
      'blocksX': 8,
      'blocksY': 8,
      'blocks': blocks,
    });
    final decoded = img.decodePng(png)!;

    for (var by = 0; by < 8; by++) {
      for (var bx = 0; bx < 8; bx++) {
        final expected = blocks[by * 8 + bx] ? 255 : 0;
        for (var y = by * 8; y < (by + 1) * 8; y++) {
          for (var x = bx * 8; x < (bx + 1) * 8; x++) {
            expect(
              decoded.getPixel(x, y).r.toInt(),
              expected,
              reason: '块 ($bx,$by) 的像素与块选择不一致',
            );
          }
        }
      }
    }
  });

  test('非 8 整除尺寸时块边界按比例映射，覆盖整幅图像', () {
    // 100x60 -> 12x7 blocks; every pixel must still land in exactly one block.
    final blocks = List<bool>.filled(12 * 7, true);
    final png = renderBlockMaskPng(<String, Object>{
      'width': 100,
      'height': 60,
      'blocksX': 12,
      'blocksY': 7,
      'blocks': blocks,
    });
    final decoded = img.decodePng(png)!;

    expect(decoded.width, 100);
    expect(decoded.height, 60);
    for (var y = 0; y < 60; y++) {
      for (var x = 0; x < 100; x++) {
        expect(decoded.getPixel(x, y).r.toInt(), 255);
      }
    }
  });
}
