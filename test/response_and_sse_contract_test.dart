import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_canvas/core/network/image_response_decoder.dart';
import 'package:novelai_canvas/data/api/gateway/dto/gateway_chat_request_dto.dart';
import 'package:novelai_canvas/data/api/gateway/dto/gateway_director_request_dto.dart';
import 'package:novelai_canvas/data/api/gateway/dto/gateway_edits_request_dto.dart';
import 'package:novelai_canvas/data/api/native/dto/native_director_request_dto.dart';
import 'package:novelai_canvas/data/api/gateway/dto/gateway_inpaint_request_dto.dart';
import 'package:novelai_canvas/data/api/native/dto/native_stream_dto.dart';

void main() {
  test('网关 OpenAI 图片响应同时支持 b64_json 与 URL', () {
    final inline = ImageResponseDecoder.decodeOpenAiImages({
      'data': [
        {
          'b64_json': base64Encode([1, 2, 3]),
          'revised_prompt': 'ok',
        },
      ],
    });
    final remote = ImageResponseDecoder.decodeOpenAiImages({
      'data': [
        {'url': 'https://example.com/image.png'},
      ],
    });

    expect(inline.single.bytes, Uint8List.fromList([1, 2, 3]));
    expect(inline.single.revisedPrompt, 'ok');
    expect(remote.single.url.toString(), 'https://example.com/image.png');
  });

  test('原生 ZIP 与 Chat Markdown 图片解码', () {
    final archive = Archive()..addFile(ArchiveFile('image.png', 3, [1, 2, 3]));
    final zip = Uint8List.fromList(ZipEncoder().encode(archive));

    expect(ImageResponseDecoder.decodeZip(zip).single.bytes, [1, 2, 3]);
    expect(
      ImageResponseDecoder.decodeChatMarkdown(
        '![image](https://example.com/a.png)',
      ).url.toString(),
      'https://example.com/a.png',
    );
  });

  test('原生 SSE 与网关 SSE 使用不同事件结构', () {
    final native = parseNativeSseData(
      'data: {"event_type":"final","samp_ix":0,"step_ix":28,"gen_id":1,"sigma":0,"image":"AQID"}',
    );
    final gateway = parseGatewayChatSseData(
      'data: {"choices":[{"delta":{"content":"![image](https://example.com/a.png)"},"finish_reason":"stop"}]}',
    );

    expect(native!.isFinal, isTrue);
    expect(native.stepIndex, 28);
    expect(gateway!.finished, isTrue);
    expect(gateway.content, contains('https://example.com'));
    expect(parseGatewayChatSseData('data: [DONE]')!.finished, isTrue);
  });

  test('Edits 同时构建 JSON 与 multipart，导演端点独立', () {
    const inpaint = GatewayInpaintRequestDto(
      model: 'nai-diffusion-4-5-full',
      prompt: 'test',
      image: 'image',
      mask: 'mask',
    );
    const builder = GatewayEditsRequestBuilder();
    expect(
      builder.build(const GatewayEditsRequestDto.json(inpaint))['mask'],
      'mask',
    );

    final multipart = builder.buildMultipart(
      GatewayEditsRequestDto.multipart(
        request: inpaint,
        imageBytes: Uint8List.fromList([1]),
        imageFilename: 'image.png',
      ),
    );
    expect(multipart.fields.any((field) => field.key == 'prompt'), isTrue);
    expect(multipart.files.single.key, 'image');

    expect(GatewayDirectorTool.declutter.path, '/v1/images/director-declutter');
    expect(
      GatewayDirectorTool.backgroundRemoval.path,
      '/v1/images/director-bg-remover',
    );
  });

  test('原生流式构建器保留三种生成 action 并仅追加 stream 字段', () {
    const builder = NativeStreamRequestBuilder();
    for (final action in ['generate', 'img2img', 'infill']) {
      final body = builder.build(
        NativeStreamRequestDto({
          'input': 'test',
          'model': 'nai-diffusion-4-5-full',
          'action': action,
          'parameters': {'width': 832, 'height': 1216},
        }),
      );
      expect(body['action'], action);
      expect((body['parameters'] as Map)['stream'], 'sse');
    }
  });

  test('原生导演工具仅为上色和表情发送 prompt 与 defry', () {
    const builder = NativeDirectorRequestBuilder();
    const commonImage = 'image';
    final declutter = builder.build(
      const NativeDirectorRequestDto(
        tool: NativeDirectorTool.declutter,
        image: commonImage,
        width: 1024,
        height: 1024,
        prompt: '不应发送',
        defry: 3,
      ),
    );
    final colorize = builder.build(
      const NativeDirectorRequestDto(
        tool: NativeDirectorTool.colorize,
        image: commonImage,
        width: 1024,
        height: 1024,
        prompt: 'orange and blue',
        defry: 1,
      ),
    );

    expect(declutter.containsKey('prompt'), isFalse);
    expect(declutter.containsKey('defry'), isFalse);
    expect(colorize['prompt'], 'orange and blue');
    expect(colorize['defry'], 1);
  });
}
