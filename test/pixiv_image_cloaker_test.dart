import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:novelai_canvas/core/storage/pixiv_image_cloaker.dart';

/// Verifies that [PixivImageCloaker] strips NAI metadata (PNG tEXt chunks and
/// alpha LSB steganography) and reads it back via [extractMetadata].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('encodeBytes removes tEXt chunks and zeroes alpha LSB', () async {
    final src = img.Image(width: 4, height: 4, numChannels: 4);
    // Odd alpha values carry the stealth payload on the LSB.
    for (final p in src) {
      p.a = (p.a.toInt() & 0xFF) | 1; // force LSB = 1 where alpha is on
    }
    // Embed a NAI-style tEXt chunk the re-encode would otherwise keep.
    (src.textData ??= {})['stealth_pngcomp'] = '{"prompt":"test"}';
    final srcBytes = Uint8List.fromList(img.encodePng(src));

    final outBytes = await PixivImageCloaker().encodeBytes(srcBytes);
    final out = img.decodePng(outBytes)!;

    expect(out.numChannels, 4);
    expect(out.textData?.containsKey('stealth_pngcomp') ?? false, isFalse);
    for (final p in out) {
      expect(p.a.toInt() & 0x01, 0, reason: 'alpha LSB must be zeroed');
    }
  });

  test('encodeBytes keeps transparency for fully transparent pixels', () async {
    final src = img.Image(width: 2, height: 2, numChannels: 4);
    for (final p in src) {
      p.a = 0; // fully transparent; LSB is already 0, must stay 0
    }
    final srcBytes = Uint8List.fromList(img.encodePng(src));

    final outBytes = await PixivImageCloaker().encodeBytes(srcBytes);
    final out = img.decodePng(outBytes)!;
    for (final p in out) {
      expect(p.a.toInt(), 0);
    }
  });

  test(
    'extractMetadata reads tEXt chunks and decompresses alpha-LSB gzip',
    () async {
      final dir = await Directory.systemTemp.createTemp('extract_test_');
      addTearDown(() => dir.delete(recursive: true));

      // Encode a stealth_pngcomp payload matching NovelAI's layout:
      // 16-byte magic `stealth_pngcomp` + 4-byte big-endian length in BITS +
      // gzip-compressed JSON.
      final jsonBytes = Uint8List.fromList(
        '{"prompt":"masterpiece","parameters":{"steps":28}}'.codeUnits,
      );
      final compressed = Uint8List.fromList(GZipEncoder().encode(jsonBytes));
      final payload = BytesBuilder()
        ..add('stealth_pngcomp'.codeUnits)
        ..addByte((compressed.length * 8) >> 24 & 0xFF)
        ..addByte((compressed.length * 8) >> 16 & 0xFF)
        ..addByte((compressed.length * 8) >> 8 & 0xFF)
        ..addByte((compressed.length * 8) & 0xFF)
        ..add(compressed);
      final payloadBits = payload.toBytes();
      // Size the image so the alpha LSBs hold the whole payload (1 bit/pixel).
      final pixelCount = payloadBits.length * 8;
      final side = ((pixelCount / 8).ceil() / 8).ceil() * 8;
      final src = img.Image(width: side, height: side, numChannels: 4);

      // Scatter the payload bits across the alpha LSBs in column-major order
      // (x outer, y inner) to match the transposed numpy layout the reader uses.
      var bitIndex = 0;
      for (var x = 0; x < src.width; x++) {
        for (var y = 0; y < src.height; y++) {
          final pixel = src.getPixel(x, y);
          final alpha = pixel.a.toInt() & 0xFE;
          final bit = bitIndex < payloadBits.length * 8
              ? (payloadBits[bitIndex >> 3] >> (7 - (bitIndex & 7))) & 0x01
              : 0;
          pixel.a = alpha | bit;
          bitIndex++;
        }
      }
      (src.textData ??= {})['Comment'] = 'hello';
      final srcPath = '${dir.path}/naive.png';
      await File(srcPath).writeAsBytes(Uint8List.fromList(img.encodePng(src)));

      final meta = await PixivImageCloaker().extractMetadata(srcPath);
      expect(meta.textChunks['Comment'], 'hello');
      expect(meta.stealthJson, isNotNull);
      expect(meta.stealthJson, contains('masterpiece'));
      expect(meta.stealthJson, contains('"steps":28'));
    },
  );

  test(
    'extractMetadata reports no stealth when alpha LSBs are clean',
    () async {
      final dir = await Directory.systemTemp.createTemp('extract_test2_');
      addTearDown(() => dir.delete(recursive: true));

      final src = img.Image(width: 4, height: 4, numChannels: 4);
      for (final p in src) {
        p.a = p.a.toInt() & 0xFE; // all LSBs zero
      }
      final srcPath = '${dir.path}/clean.png';
      await File(srcPath).writeAsBytes(Uint8List.fromList(img.encodePng(src)));

      final meta = await PixivImageCloaker().extractMetadata(srcPath);
      expect(meta.stealthJson, isNull);
    },
  );
}
