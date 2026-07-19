import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class GenerationImageStore {
  const GenerationImageStore();

  Future<StoredGenerationImage> save({
    required String taskId,
    required Uint8List bytes,
    String extension = 'png',
  }) async {
    final support = await getApplicationSupportDirectory();
    final imageDirectory = Directory(p.join(support.path, 'generation_images'));
    final thumbnailDirectory = Directory(p.join(support.path, 'thumbnails'));
    await imageDirectory.create(recursive: true);
    await thumbnailDirectory.create(recursive: true);

    final digest = sha256.convert(bytes).toString().substring(0, 16);
    final imagePath = p.join(
      imageDirectory.path,
      '${taskId}_$digest.$extension',
    );
    await File(imagePath).writeAsBytes(bytes, flush: true);

    final decoded = img.decodeImage(bytes);
    String? thumbnailPath;
    if (decoded != null) {
      final thumbnail = img.copyResize(decoded, width: 384);
      thumbnailPath = p.join(thumbnailDirectory.path, '${taskId}_$digest.jpg');
      await File(
        thumbnailPath,
      ).writeAsBytes(img.encodeJpg(thumbnail, quality: 82));
    }
    return StoredGenerationImage(
      imagePath: imagePath,
      thumbnailPath: thumbnailPath,
    );
  }
}

class StoredGenerationImage {
  const StoredGenerationImage({
    required this.imagePath,
    required this.thumbnailPath,
  });
  final String imagePath;
  final String? thumbnailPath;
}
