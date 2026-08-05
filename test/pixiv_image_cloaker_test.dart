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

  group('PixivMetadataParser', () {
    test('parses flat NAI payload into readable fields', () {
      const json =
          '{"prompt":"masterpiece, 1girl","uc":"lowres, bad hands",'
          '"sampler":"k_euler_ancestral","steps":28,"seed":629328648,'
          '"width":832,"height":1216,"scale":5.0,"noise_schedule":"karras",'
          '"signed_hash":"vs09nedmq8yb=="}';
      final meta = PixivMetadataParser.parse(json);
      expect(meta.prompt, 'masterpiece, 1girl');
      expect(meta.negativePrompt, 'lowres, bad hands');
      expect(meta.sampler, 'k_euler_ancestral');
      expect(meta.steps, 28);
      expect(meta.seed, 629328648);
      expect(meta.width, 832);
      expect(meta.height, 1216);
      expect(meta.scale, 5.0);
      expect(meta.noiseSchedule, 'karras');
      expect(meta.signedHash, 'vs09nedmq8yb==');
      expect(meta.stealthJson, json);
    });

    test('parses v4 nested layout with char captions', () {
      const json =
          '{"v4_prompt":{"caption":{"base_caption":"masterwork, best quality",'
          '"char_captions":[{"char_caption":"elysia, 1girl, long hair",'
          '"centers":[{"x":0.5,"y":0.5}]}]}},'
          '"v4_negative_prompt":{"caption":{"base_caption":"lowres, bad anatomy"}},'
          '"sampler":"k_euler","steps":28,"seed":1,"width":832,"height":1216,'
          '"scale":5.0,"signed_hash":"abc=="}';
      final meta = PixivMetadataParser.parse(json);
      expect(meta.prompt, contains('masterwork, best quality'));
      expect(meta.prompt, contains('elysia, 1girl, long hair'));
      expect(meta.negativePrompt, 'lowres, bad anatomy');
      expect(meta.sampler, 'k_euler');
      expect(meta.steps, 28);
      expect(meta.signedHash, 'abc==');
    });

    test('returns raw-only metadata for invalid JSON', () {
      final meta = PixivMetadataParser.parse('not-json');
      expect(meta.stealthJson, 'not-json');
      expect(meta.prompt, isNull);
    });
  });
}
