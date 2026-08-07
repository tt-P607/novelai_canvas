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
/// [textChunks] holds the plain tEXt/iTXt blocks read directly from the file.
/// [stealthJson] is the decompressed `stealth_pngcomp` payload hidden in the
/// alpha channel LSBs (gzip-compressed JSON), while [prompt]/[negativePrompt]/
/// [sampler]/... are the same payload parsed into human-readable fields.
class PixivImageMetadata {
  const PixivImageMetadata({
    required this.textChunks,
    required this.stealthJson,
    this.prompt,
    this.negativePrompt,
    this.sampler,
    this.steps,
    this.seed,
    this.width,
    this.height,
    this.scale,
    this.noiseSchedule,
    this.signedHash,
  });

  final Map<String, String> textChunks;
  final String? stealthJson;

  final String? prompt;
  final String? negativePrompt;
  final String? sampler;
  final int? steps;
  final int? seed;
  final int? width;
  final int? height;
  final double? scale;
  final String? noiseSchedule;
  final String? signedHash;
}

/// Parses NAI metadata into displayable fields. NAI stores its payload either
/// in the PNG tEXt `Comment` chunk (a JSON string — the default) or in the
/// alpha-LSB `stealth_pngcomp` payload. Both are merged, with the `Comment`
/// chunk taking priority. Understands the flat layout
/// (prompt/uc/sampler/steps/seed/...) and the v4 nested layout
/// (`v4_prompt.caption.base_caption` + `char_captions`).
class PixivMetadataParser {
  const PixivMetadataParser();

  static PixivImageMetadata parse(String json) {
    return parseWithChunks(const {}, stealthJson: json);
  }

  /// Parses from PNG text chunks (tEXt/iTXt) and an optional alpha-LSB JSON
  /// payload. The tEXt `Comment` chunk usually holds the full NAI JSON string;
  /// when absent, the stealth payload is used. Other chunks like `Title` /
  /// `Description` / `Software` / `Source` are kept for display.
  static PixivImageMetadata parseWithChunks(
    Map<String, String> chunks, {
    String? stealthJson,
  }) {
    final data = <String, dynamic>{};
    String? rawJson = stealthJson;

    // The Comment chunk may itself be a JSON object (NAI default), and it
    // usually carries the same payload as the stealth LSB stream.
    final comment = chunks['Comment'];
    if (comment != null && comment.isNotEmpty) {
      final decoded = _tryDecodeObject(comment);
      if (decoded != null) {
        data.addAll(decoded);
        rawJson = comment;
      }
    }
    // The stealth payload is also a JSON object (alpha-LSB source).
    if (stealthJson != null && stealthJson.isNotEmpty) {
      final decoded = _tryDecodeObject(stealthJson);
      if (decoded != null) {
        for (final entry in decoded.entries) {
          data.putIfAbsent(entry.key, () => entry.value);
        }
        rawJson ??= stealthJson;
      }
    }
    // Merge flat fields from other chunks (Title/Description/Software/...).
    for (final entry in chunks.entries) {
      if (entry.key == 'Comment') continue;
      data.putIfAbsent(entry.key, () => entry.value);
    }

    return PixivImageMetadata(
      textChunks: chunks,
      stealthJson: rawJson,
      prompt: _prompt(data),
      negativePrompt: _negativePrompt(data),
      sampler: _string(data, 'sampler'),
      steps: _int(data, 'steps'),
      seed: _int(data, 'seed'),
      width: _int(data, 'width'),
      height: _int(data, 'height'),
      scale: _double(data, 'scale'),
      noiseSchedule: _string(data, 'noise_schedule'),
      signedHash: _string(data, 'signed_hash'),
    );
  }

  static Map<String, dynamic>? _tryDecodeObject(String value) {
    try {
      final raw = jsonDecode(value);
      if (raw is Map) return Map<String, dynamic>.from(raw);
    } catch (_) {
      // Not JSON — treat as a plain text chunk.
    }
    return null;
  }

  /// Top-level `prompt`, or the v4 base caption plus each character caption.
  static String? _prompt(Map<String, dynamic> data) {
    final flat = _string(data, 'prompt');
    if (flat != null && flat.isNotEmpty) return flat;
    final v4 = data['v4_prompt'];
    if (v4 is Map) {
      final parts = <String>[];
      final caption = v4['caption'];
      if (caption is Map) {
        final base = caption['base_caption'];
        if (base is String && base.isNotEmpty) parts.add(base);
        final chars = caption['char_captions'];
        if (chars is List) {
          for (final c in chars) {
            if (c is Map && c['char_caption'] is String) {
              parts.add(c['char_caption'] as String);
            }
          }
        }
      }
      if (parts.isNotEmpty) return parts.join('\n');
    }
    return flat;
  }

  /// Top-level `uc`, or the v4 negative caption.
  static String? _negativePrompt(Map<String, dynamic> data) {
    final flat = _string(data, 'uc');
    if (flat != null && flat.isNotEmpty) return flat;
    final v4 = data['v4_negative_prompt'];
    if (v4 is Map && v4['caption'] is Map) {
      final base = (v4['caption'] as Map)['base_caption'];
      if (base is String && base.isNotEmpty) return base;
    }
    return flat;
  }

  static String? _string(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  static int? _int(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is int ? value : null;
  }

  static double? _double(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return null;
  }
}

/// Strips NAI metadata from a PNG and reads it back for inspection. Used by the
/// image-tools "NAI 元数据" extract/strip feature.
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
    final outDir = Directory(p.join(dir.path, 'nai_cloak'));
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

  // Prefer the tEXt `Comment` chunk (NAI's default storage), fall back to the
  // alpha-LSB stealth payload. Both may be present and carry the same fields.
  return PixivMetadataParser.parseWithChunks(
    textChunks,
    stealthJson: stealthJson,
  );
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
