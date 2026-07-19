import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../common/api_request_builder.dart';
import 'gateway_inpaint_request_dto.dart';

class GatewayEditsRequestDto {
  const GatewayEditsRequestDto.json(this.request)
    : imageBytes = null,
      maskBytes = null,
      imageFilename = null,
      maskFilename = null;

  const GatewayEditsRequestDto.multipart({
    required this.request,
    required this.imageBytes,
    required this.imageFilename,
    this.maskBytes,
    this.maskFilename,
  });

  final GatewayInpaintRequestDto request;
  final Uint8List? imageBytes;
  final Uint8List? maskBytes;
  final String? imageFilename;
  final String? maskFilename;

  bool get isMultipart => imageBytes != null;
}

class GatewayEditsRequestBuilder
    implements ApiRequestBuilder<GatewayEditsRequestDto> {
  const GatewayEditsRequestBuilder();
  @override
  int get templateVersion => 1;
  @override
  JsonMap build(
    GatewayEditsRequestDto request, {
    List<JsonMap> patches = const [],
  }) => const GatewayInpaintRequestBuilder().build(
    request.request,
    patches: patches,
  );

  FormData buildMultipart(GatewayEditsRequestDto request) {
    if (!request.isMultipart) {
      throw ArgumentError('当前 Edits 请求不是 multipart 模式。');
    }
    final data = build(request);
    data.remove('image');
    data.remove('mask');
    return FormData.fromMap({
      ...data,
      'image': MultipartFile.fromBytes(
        request.imageBytes!,
        filename: request.imageFilename,
      ),
      if (request.maskBytes != null)
        'mask': MultipartFile.fromBytes(
          request.maskBytes!,
          filename: request.maskFilename ?? 'mask.png',
        ),
    });
  }
}
