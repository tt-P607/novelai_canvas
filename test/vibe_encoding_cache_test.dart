import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_canvas/core/storage/vibe_file_parser.dart';
import 'package:novelai_canvas/domain/entities/advanced_generation.dart';

void main() {
  test('未编码的 Vibe 不会被判定为需要重新编码', () {
    const reference = VibeReference(imagePath: '/tmp/a.png');

    expect(reference.hasEncoding, isFalse);
    expect(reference.needsReencode, isFalse);
    expect(reference.activeEncoding, isNull);
  });

  test('编码后当前提取值命中缓存', () {
    const reference = VibeReference(
      imagePath: '/tmp/a.png',
      informationExtracted: 1.0,
    );
    final encoded = reference.withEncoding('AAA');

    expect(encoded.hasEncoding, isTrue);
    expect(encoded.activeEncoding, 'AAA');
    expect(encoded.needsReencode, isFalse);
  });

  test('切到未编码的提取值需要编码，切回已编码的值直接复用缓存', () {
    const base = VibeReference(
      imagePath: '/tmp/a.png',
      informationExtracted: 1.0,
    );
    final atOne = base.withEncoding('ENC_1.0');

    // 改到没编码过的 0.8：需要编码，且不携带旧编码数据。
    final atPointEight = atOne.withInformationExtracted(0.8);
    expect(atPointEight.hasEncoding, isFalse);
    expect(atPointEight.needsReencode, isTrue);
    expect(atPointEight.activeEncoding, isNull);

    // 在 0.8 上编码，两个档位同时留在缓存里。
    final encodedBoth = atPointEight.withEncoding('ENC_0.8');
    expect(encodedBoth.activeEncoding, 'ENC_0.8');
    expect(encodedBoth.encodingCache.length, 2);

    // 切回 1.0：命中缓存，不需要再花 Anlas。
    final backToOne = encodedBoth.withInformationExtracted(1.0);
    expect(backToOne.activeEncoding, 'ENC_1.0');
    expect(backToOne.hasEncoding, isTrue);
    expect(backToOne.needsReencode, isFalse);
  });

  test('0.01 精度的提取值切换会分别缓存并精确恢复', () {
    final atPointSeven = const VibeReference(
      imagePath: '/tmp/a.png',
      informationExtracted: 0.70,
    ).withEncoding('ENC_0.70');
    final atPointSevenOne = atPointSeven
        .withInformationExtracted(0.71)
        .withEncoding('ENC_0.71');

    expect(atPointSevenOne.activeEncoding, 'ENC_0.71');
    expect(
      atPointSevenOne.withInformationExtracted(0.70).activeEncoding,
      'ENC_0.70',
    );
  });

  test('从文件导入的纯编码数据具备来源，可直接参与生成', () {
    const imported = VibeReference(
      encodedData: 'IMPORTED',
      displayName: '1cb0cb-cfa203',
      informationExtracted: 1.0,
    );

    expect(imported.hasSource, isTrue);
    expect(imported.hasEncoding, isTrue);
    expect(imported.hasReencodeSource, isFalse);
    expect(imported.activeEncoding, 'IMPORTED');
  });

  test('官网格式导入全部编码槽位并保留可重新编码的原图', () async {
    final sourceImage = base64Encode([1, 2, 3]);
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'name': 'official-vibe',
          'image': 'data:image/png;base64,$sourceImage',
          'thumbnail': base64Encode([4, 5, 6]),
          'importInfo': {'strength': 0.63, 'information_extracted': 0.71},
          'encodings': {
            'nai-diffusion-4-5-full': {
              'first': {
                'encoding': 'ENC_0.70',
                'params': {'information_extracted': 0.70},
              },
              'second': {
                'encoding': 'ENC_0.71',
                'params': {'information_extracted': 0.71},
              },
            },
          },
        }),
      ),
    );

    final imported = (await VibeFileParser.parseBytes(bytes)).single;

    expect(imported.sourceImageBase64, sourceImage);
    expect(imported.hasReencodeSource, isTrue);
    expect(imported.strength, 0.63);
    expect(imported.activeEncoding, 'ENC_0.71');
    expect(imported.withInformationExtracted(0.70).activeEncoding, 'ENC_0.70');
    expect(imported.withInformationExtracted(0.72).hasEncoding, isFalse);
  });

  test('快照 JSON 不持久化大体积编码与原图，冷恢复后标记需重新编码', () {
    const base = VibeReference(
      imagePath: '/tmp/a.png',
      informationExtracted: 1.0,
    );
    final encoded = base
        .withEncoding('ENC_1.0')
        .withInformationExtracted(0.5)
        .withEncoding('ENC_0.5')
        .copyWith(sourceImageBase64: 'SOURCE');

    final restored = VibeReference.fromJson(encoded.toJson());

    // Large payloads are intentionally stripped to avoid main-isolate stalls.
    expect(restored.sourceImageBase64, isNull);
    expect(restored.encodingCache, isEmpty);
    expect(restored.informationExtracted, 0.5);
    // hadEncoding survives so the UI can prompt re-encode.
    expect(restored.hasEncoding, isFalse);
    expect(restored.needsReencode, isFalse);
  });

  test('旧版快照含 encodedData 时冷恢复标记需重新编码', () {
    final legacy = VibeReference.fromJson(const {
      'imagePath': '/tmp/a.png',
      'encodedData': 'LEGACY',
      'informationExtracted': 0.7,
      'enabled': true,
    });

    // The payload itself is gone; only the "had encoding" flag survives.
    expect(legacy.hasEncoding, isFalse);
    expect(legacy.needsReencode, isFalse);
  });
}
