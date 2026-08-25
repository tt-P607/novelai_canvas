import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_canvas/domain/entities/model_info.dart';

void main() {
  group('BuiltInModels V5 能力规则', () {
    test('内置目录包含 V5 Full 与 V5 Curated，且排在最前', () {
      final ids = BuiltInModels.all.map((m) => m.id).toList();
      expect(ids.take(2), ['nai-diffusion-5-full', 'nai-diffusion-5-curated']);
    });

    test('V5 判定与标注名称', () {
      expect(BuiltInModels.isV5('nai-diffusion-5-full'), isTrue);
      expect(BuiltInModels.isV5('nai-diffusion-5-curated'), isTrue);
      expect(BuiltInModels.isV5('nai-diffusion-4-5-full'), isFalse);
      expect(
        BuiltInModels.nameFor('nai-diffusion-5-full'),
        'NAI Diffusion V5 Full',
      );
    });

    test('V5 不支持 Vibe 与角色参考', () {
      for (final model in ['nai-diffusion-5-full', 'nai-diffusion-5-curated']) {
        expect(
          BuiltInModels.supportsVibe(model),
          isFalse,
          reason: '$model 不应支持 Vibe',
        );
        expect(
          BuiltInModels.supportsCharacterReference(model),
          isFalse,
          reason: '$model 不应支持角色参考',
        );
      }
    });

    test('V4.5 支持 Vibe 与角色参考', () {
      expect(BuiltInModels.supportsVibe('nai-diffusion-4-5-full'), isTrue);
      expect(
        BuiltInModels.supportsCharacterReference('nai-diffusion-4-5-full'),
        isTrue,
      );
    });

    test('V4 支持 Vibe 但不支持角色参考', () {
      expect(BuiltInModels.supportsVibe('nai-diffusion-4-full'), isTrue);
      expect(
        BuiltInModels.supportsCharacterReference('nai-diffusion-4-full'),
        isFalse,
      );
    });

    test('局部重绘模型映射', () {
      expect(
        BuiltInModels.inpaintModelFor('nai-diffusion-5-full'),
        'nai-diffusion-5-full-inpainting',
      );
      expect(
        BuiltInModels.inpaintModelFor('nai-diffusion-5-curated'),
        'nai-diffusion-5-full-inpainting',
      );
      expect(
        BuiltInModels.inpaintModelFor('nai-diffusion-4-5-full'),
        'nai-diffusion-4-5-full-inpainting',
      );
      expect(
        BuiltInModels.inpaintModelFor('nai-diffusion-5-full-inpainting'),
        'nai-diffusion-5-full-inpainting',
      );
    });
  });
}
