import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Converts a painted mask PNG into the block-aligned binary mask NovelAI
/// expects, mirroring novelai-sdk's `mask_to_base64` pipeline.
///
/// The VAE operates on 8x8 pixel blocks in latent space. A mask whose edge
/// cuts through the middle of a block leaves that block half-inpainted, which
/// renders as the grey jagged fringe along stroke borders. Averaging each 8x8
/// block (BOX downscale), thresholding at the block level, then expanding back
/// with nearest-neighbour makes every block fully in or fully out.
///
/// Call via `compute()`: full-resolution masks are several megapixels.
Uint8List binarizeMaskToVaeGrid(Uint8List pngBytes) {
  final decoded = img.decodePng(pngBytes);
  if (decoded == null) throw StateError('无法处理蒙版 PNG。');
  final width = decoded.width;
  final height = decoded.height;
  final blocksX = width ~/ 8 > 0 ? width ~/ 8 : 1;
  final blocksY = height ~/ 8 > 0 ? height ~/ 8 : 1;

  // BOX downscale: average brightness per 8x8 block, then binarise.
  final blockOn = List<bool>.filled(blocksX * blocksY, false);
  for (var by = 0; by < blocksY; by++) {
    for (var bx = 0; bx < blocksX; bx++) {
      var sum = 0;
      var count = 0;
      final startX = bx * width ~/ blocksX;
      final endX = (bx + 1) * width ~/ blocksX;
      final startY = by * height ~/ blocksY;
      final endY = (by + 1) * height ~/ blocksY;
      for (var y = startY; y < endY; y++) {
        for (var x = startX; x < endX; x++) {
          sum += decoded.getPixel(x, y).r.toInt();
          count++;
        }
      }
      blockOn[by * blocksX + bx] = count > 0 && sum / count > 127;
    }
  }

  // Nearest-neighbour expansion back to full size, opaque RGBA like the SDK.
  final mask = img.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y++) {
    final by = (y * blocksY ~/ height).clamp(0, blocksY - 1);
    for (var x = 0; x < width; x++) {
      final bx = (x * blocksX ~/ width).clamp(0, blocksX - 1);
      final value = blockOn[by * blocksX + bx] ? 255 : 0;
      mask.setPixelRgba(x, y, value, value, value, 255);
    }
  }
  return img.encodePng(mask);
}
