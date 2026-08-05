import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// NAI metadata extracted from a PNG before upload (the inverse of [cloak]).
///
/// [textChunks] holds the plain tEXt/iTXt blocks read directly from the file,
/// while [stealthJson] is the decompressed `stealth_pngcomp` payload hidden in
/// the alpha channel LSBs (gzip-compressed JSON with the full prompt,
/// parameters and model signature).
class PixivImageMetadata {
  const PixivImageMetadata({
    required this.textChunks,
    required this.stealthJson,
  });

  final Map<String, String> textChunks;
  final String? stealthJson;
}

/// Strips NAI metadata from a PNG before uploading to Pixiv, and reads it back
/// for inspection.
///
/// Two areas are handled:
/// 1. PNG tEXt/iTXt chunks — removed by re-encoding (img.encodePng drops
///    ancillary chunks) or read directly from [img.Image.textData].
/// 2. Alpha channel LSB steganography — every pixel's alpha LSB is zeroed on
///    strip (alpha & 0xFE), destroying the `stealth_pngcomp` gzip JSON and the
///    model signature hash while keeping transparency intact. Reading collects
///    those LSBs into a byte stream and gzip-decompresses the payload.
class PixivImageCloaker {
  Future<String> cloak(String inputPath) async {
    final bytes = await File(inputPath).readAsBytes();
    final outBytes = await encodeBytes(bytes);

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

  /// Strips NAI metadata from raw PNG bytes (tEXt chunks + alpha LSBs) on a
  /// background isolate. Exposed for testing without file I/O.
  Future<Uint8List> encodeBytes(Uint8List pngBytes) {
    return compute<_CloakInput, Uint8List>(
      _cloakIsolate,
      _CloakInput(pngBytes: pngBytes),
    );
  }

  /// Reads NAI metadata from a PNG: plain tEXt/iTXt chunks plus the
  /// decompressed alpha-LSB `stealth_pngcomp` payload, if any. CPU-heavy
  /// decoding runs on a background isolate.
  Future<PixivImageMetadata> extractMetadata(String inputPath) async {
    final bytes = await File(inputPath).readAsBytes();
    return compute(_extractIsolate, Uint8List.fromList(bytes));
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

  // img.encodePng preserves textData as tEXt chunks, so clear it explicitly —
  // re-encoding alone does not strip NAI's textual metadata.
  rgba.textData?.clear();

  // Zero out the LSB of every pixel's alpha channel. This destroys any
  // stealth_pngcomp payload (magic + length + gzip JSON) and the model
  // signature hash that NAI embeds, without touching visible transparency.
  for (final pixel in rgba) {
    pixel.a = (pixel.a.toInt() & 0xFE);
  }

  final outBytes = img.encodePng(rgba, level: 6);
  return Uint8List.fromList(outBytes);
}

PixivImageMetadata _extractIsolate(Uint8List pngBytes) {
  final decoded = img.decodeImage(pngBytes);
  if (decoded == null) {
    throw StateError('PNG 解码失败');
  }

  final textChunks = Map<String, String>.from(decoded.textData ?? const {});

  String? stealthJson;
  if (decoded.hasAlpha) {
    final rgba = decoded.numChannels == 4
        ? decoded
        : decoded.convert(numChannels: 4);
    final lsb = _collectAlphaLsb(rgba);
    final payload = _parseStealthPayload(lsb);
    if (payload != null) {
      try {
        stealthJson = utf8.decode(GZipDecoder().decodeBytes(payload));
      } catch (_) {
        // Not a valid gzip stream; keep the raw payload so the user can still
        // see what was embedded.
        stealthJson = utf8.decode(payload, allowMalformed: true);
      }
    }
  }

  return PixivImageMetadata(textChunks: textChunks, stealthJson: stealthJson);
}

/// Collects the alpha LSBs into a byte stream following NAI's layout: the
/// alpha channel is transposed (column-major: x outer, y inner) then each
/// 8-bit group is packed MSB-first (numpy `alpha.T.reshape(-1)` +
/// `packbits(axis=1)` with default big-endian bit order).
Uint8List _collectAlphaLsb(img.Image image) {
  final rgba = image.numChannels == 4 ? image : image.convert(numChannels: 4);
  final bytes = rgba.getBytes(order: img.ChannelOrder.rgba);

  final totalPixels = rgba.width * rgba.height;
  final usablePixels = totalPixels & ~7; // multiple of 8
  final out = BytesBuilder(copy: false);
  var accumulator = 0;
  var bitCount = 0;
  for (var i = 0; i < usablePixels; i++) {
    // Column-major index over an RGBA buffer (stride 4).
    final col = i ~/ rgba.height;
    final row = i % rgba.height;
    final alpha = bytes[(row * rgba.width + col) * 4 + 3];
    accumulator = (accumulator << 1) | (alpha & 0x01);
    bitCount++;
    if (bitCount == 8) {
      out.addByte(accumulator);
      accumulator = 0;
      bitCount = 0;
    }
  }
  return out.toBytes();
}

/// NAI's stealth_pngcomp layout: 16-byte magic `stealth_pngcomp`, 4-byte
/// big-endian payload length in BITS, then the gzip-compressed JSON.
Uint8List? _parseStealthPayload(Uint8List lsb) {
  const magic = 'stealth_pngcomp';
  if (lsb.length < magic.length + 4) return null;
  final readMagic = utf8.decode(
    lsb.sublist(0, magic.length),
    allowMalformed: true,
  );
  if (readMagic != magic) return null;
  final lengthBits =
      (lsb[magic.length] << 24) |
      (lsb[magic.length + 1] << 16) |
      (lsb[magic.length + 2] << 8) |
      lsb[magic.length + 3];
  final length = lengthBits ~/ 8;
  final start = magic.length + 4;
  if (length <= 0 || start + length > lsb.length) return null;
  return lsb.sublist(start, start + length);
}
