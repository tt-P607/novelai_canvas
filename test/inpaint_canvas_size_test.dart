import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:novelai_canvas/core/storage/image_size_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('源图尺寸读取返回真实像素宽高，用于对齐蒙版画布', () async {
    final directory = await Directory.systemTemp.createTemp('mask_size');
    addTearDown(() => directory.delete(recursive: true));

    final path = '${directory.path}/source.png';
    await File(
      path,
    ).writeAsBytes(img.encodePng(img.Image(width: 1216, height: 832)));

    expect(await readImageSize(path), (1216, 832));
  });

  test('无法解码的文件返回 null，调用方保留原画幅', () async {
    final directory = await Directory.systemTemp.createTemp('mask_size');
    addTearDown(() => directory.delete(recursive: true));

    final path = '${directory.path}/broken.png';
    await File(path).writeAsString('not an image');

    expect(await readImageSize(path), isNull);
  });
}
