import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Preprocesses character reference images the same way the official
/// novelai-sdk does: resize to 1024x1536 keeping the aspect ratio and pad
/// with centered black bars, then return as base64 PNG.
///
/// NovelAI's director-reference upstream rejects raw images of arbitrary
/// dimensions with HTTP 400, so every reference image must be normalized
/// before being sent.
abstract final class CharacterReferencePreprocessor {
  static const int targetWidth = 1024;
  static const int targetHeight = 1536;

  static String process(Uint8List rawBytes) {
    final source = img.decodeImage(rawBytes);
    if (source == null) {
      throw FormatException('无法解码角色参考图片。');
    }
    final rgb = source.convert(numChannels: 3);
    final srcW = rgb.width;
    final srcH = rgb.height;
    final srcRatio = srcW / srcH;
    final targetRatio = targetWidth / targetHeight;

    int newW;
    int newH;
    if (srcRatio > targetRatio) {
      newW = targetWidth;
      newH = (targetWidth / srcRatio).round();
    } else {
      newH = targetHeight;
      newW = (targetHeight * srcRatio).round();
    }

    final resized = img.copyResize(
      rgb,
      width: newW,
      height: newH,
      interpolation: img.Interpolation.linear,
    );

    final background = img.Image(
      width: targetWidth,
      height: targetHeight,
      numChannels: 3,
    );
    // Fill with black.
    img.fill(background, color: img.ColorRgb8(0, 0, 0));
    final offsetX = (targetWidth - newW) ~/ 2;
    final offsetY = (targetHeight - newH) ~/ 2;
    img.compositeImage(background, resized, dstX: offsetX, dstY: offsetY);

    final png = img.encodePng(background);
    return base64Encode(png);
  }
}
