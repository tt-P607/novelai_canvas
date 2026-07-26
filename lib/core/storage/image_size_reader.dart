import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Reads the pixel dimensions of an image file as `(width, height)`.
///
/// Decoding happens off the UI isolate because full-resolution PNGs block the
/// main thread long enough to drop frames. Returns null when the file is
/// missing or not a decodable image.
Future<(int, int)?> readImageSize(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    return compute(_decodeSize, bytes);
  } catch (_) {
    return null;
  }
}

(int, int)? _decodeSize(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  return (decoded.width, decoded.height);
}
