import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_canvas/core/network/json_patch_applier.dart';
import 'package:novelai_canvas/data/api/native/dto/native_generation_parameters_dto.dart';
import 'package:novelai_canvas/data/api/native/dto/native_image_to_image_request_dto.dart';
import 'package:novelai_canvas/data/api/native/dto/native_inpaint_request_dto.dart';
import 'package:novelai_canvas/data/api/native/dto/native_text_to_image_request_dto.dart';

void main() {
  const parameters = NativeGenerationParametersDto(
    width: 832,
    height: 1216,
    seed: 42,
    negativePrompt: 'lowres',
    v4Prompt: V4PromptDto(baseCaption: '1girl'),
    v4NegativePrompt: V4PromptDto(baseCaption: 'lowres', legacyUc: false),
  );

  test('原生文生图黄金请求保持独立 action 与模板版本', () {
    const builder = NativeTextToImageRequestBuilder();
    final json = builder.build(
      const NativeTextToImageRequestDto(
        prompt: '1girl',
        model: 'nai-diffusion-4-5-full',
        parameters: parameters,
      ),
    );

    expect(builder.templateVersion, 1);
    expect(json['action'], 'generate');
    expect(json['input'], '1girl');
    expect((json['parameters'] as Map)['params_version'], 3);
    expect((json['parameters'] as Map)['width'], 832);
  });

  test('图生图与局部重绘构建器不共享可变请求体', () {
    final imageRequest = NativeImageToImageRequestDto(
      prompt: 'img2img',
      model: 'nai-diffusion-4-5-full',
      parameters: parameters,
      image: 'source',
    );
    final inpaintRequest = NativeInpaintRequestDto(
      prompt: 'inpaint',
      model: 'nai-diffusion-4-5-full',
      parameters: parameters,
      image: 'source',
      mask: 'mask',
    );
    final imageJson = const NativeImageToImageRequestBuilder().build(
      imageRequest,
    );
    final inpaintJson = const NativeInpaintRequestBuilder().build(
      inpaintRequest,
    );

    expect(imageJson['action'], 'img2img');
    expect(inpaintJson['action'], 'infill');
    expect(inpaintJson['model'], 'nai-diffusion-4-5-full-inpainting');
    expect((imageJson['parameters'] as Map).containsKey('mask'), isFalse);
    expect((inpaintJson['parameters'] as Map)['mask'], 'mask');
  });

  test('JSON Patch 可覆盖单个端点请求且不修改源对象', () {
    final source = <String, Object?>{
      'parameters': <String, Object?>{'steps': 28, 'tags': <Object?>[]},
    };
    final patched = JsonPatchApplier.apply(source, const [
      {'op': 'replace', 'path': '/parameters/steps', 'value': 32},
      {'op': 'add', 'path': '/parameters/tags/-', 'value': 'test'},
    ]);

    expect((patched['parameters'] as Map)['steps'], 32);
    expect((patched['parameters'] as Map)['tags'], ['test']);
    expect((source['parameters'] as Map)['steps'], 28);
  });
}
