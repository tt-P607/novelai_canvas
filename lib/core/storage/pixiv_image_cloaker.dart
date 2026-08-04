import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

/// Strips NAI metadata from a PNG before uploading to Pixiv.
///
/// Two areas are cleaned:
/// 1. PNG tEXt/iTXt chunks — removed by re-encoding (img.encodePng drops
///    ancillary chunks).
/// 2. Alpha channel LSB steganography — every pixel's alpha is zeroed on
///    its lowest bit (alpha & 0xFE). This wipes both the NAI stealth_pngcomp
///    prompt JSON and the model signature hash, while keeping transparency
///    intact (a delta of 1 in alpha is imperceptible to the human eye).
class PixivImageCloaker {
  Future<String> cloak(String inputPath) async {
    final bytes = await File(inputPath).readAsBytes();

    final outBytes = await compute<_CloakInput, Uint8List>(
      _cloakIsolate,
      _CloakInput(pngBytes: bytes),
    );

    final dir = await getTemporaryDirectory();
    final outDir = Directory(p.join(dir.path, 'pixiv_cloak'));
    if (!await outDir.exists()) await outDir.create(recursive: true);
    final outPath = p.join(
      outDir.path,
      '${const Uuid().v4()}_${p.basename(inputPath)}',
    );
    await File(outPath).writeAsBytes(outBytes);
    return outPath;
  }
}

class _CloakInput {
  final Uint8List pngBytes;
  _CloakInput({required this.pngBytes});
}

Uint8List _cloakIsolate(_CloakInput input) {
  final decoded = img.decodeImage(input.pngBytes);
  if (decoded == null) {
    throw StateError('PNG 解码失败');
  }

  final rgba = decoded.numChannels == 4
      ? decoded
      : decoded.convert(numChannels: 4);

  // Zero out the LSB of every pixel's alpha channel. This destroys any
  // stealth_pngcomp payload (magic + length + gzip JSON) and the model
  // signature hash that NAI embeds, without touching visible transparency.
  for (final pixel in rgba) {
    pixel.a = (pixel.a.toInt() & 0xFE);
  }

  final outBytes = img.encodePng(rgba, level: 6);
  return Uint8List.fromList(outBytes);
}
