import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Renders a block-grid mask selection into the binary RGBA PNG NovelAI
/// expects, mirroring novelai-sdk's `mask_to_base64` output format.
///
/// The VAE operates on 8x8 pixel blocks in latent space, so the editor selects
/// whole blocks; every block is either fully inpainted (white) or fully kept
/// (black), which eliminates the grey half-inpainted fringe along edges.
///
/// [args] keys: `width`, `height`, `blocksX`, `blocksY` (ints) and `blocks`
/// (List&lt;bool&gt; of length blocksX*blocksY, row-major). Passed as a map so the
/// whole payload crosses the isolate boundary in one `compute()` call.
Uint8List renderBlockMaskPng(Map<String, Object> args) {
  final width = args['width']! as int;
  final height = args['height']! as int;
  final blocksX = args['blocksX']! as int;
  final blocksY = args['blocksY']! as int;
  final blocks = (args['blocks']! as List).cast<bool>();

  final mask = img.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y++) {
    final by = (y * blocksY ~/ height).clamp(0, blocksY - 1);
    for (var x = 0; x < width; x++) {
      final bx = (x * blocksX ~/ width).clamp(0, blocksX - 1);
      final value = blocks[by * blocksX + bx] ? 255 : 0;
      mask.setPixelRgba(x, y, value, value, value, 255);
    }
  }
  return img.encodePng(mask);
}
