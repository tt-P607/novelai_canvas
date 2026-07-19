import '../../common/api_request_builder.dart';

class GatewayVibeTransferRequestDto {
  const GatewayVibeTransferRequestDto({
    required this.model,
    required this.prompt,
    this.referenceImage,
    this.referenceImages = const [],
    this.encodedReferences = const [],
    this.referenceStrength = 0.7,
    this.referenceStrengths = const [],
    this.informationExtracted = 1,
    this.informationExtractedValues = const [],
    this.width,
    this.height,
    this.size,
    this.responseFormat = 'url',
  });
  final String model;
  final String prompt;
  final String? referenceImage;
  final List<String> referenceImages;
  final List<String> encodedReferences;
  final double referenceStrength;
  final List<double> referenceStrengths;
  final double informationExtracted;
  final List<double> informationExtractedValues;
  final int? width;
  final int? height;
  final String? size;
  final String responseFormat;
}

class GatewayVibeTransferRequestBuilder
    implements ApiRequestBuilder<GatewayVibeTransferRequestDto> {
  const GatewayVibeTransferRequestBuilder();
  @override
  int get templateVersion => 1;
  @override
  JsonMap build(
    GatewayVibeTransferRequestDto request, {
    List<JsonMap> patches = const [],
  }) => applyRequestPatches({
    'model': request.model,
    'prompt': request.prompt,
    if (request.referenceImage != null)
      'reference_image': request.referenceImage,
    if (request.referenceImages.isNotEmpty)
      'reference_images': request.referenceImages,
    if (request.encodedReferences.isNotEmpty)
      'reference_image_multiple': request.encodedReferences,
    'reference_strength': request.referenceStrength,
    if (request.referenceStrengths.isNotEmpty)
      'reference_strength_multiple': request.referenceStrengths,
    'reference_information_extracted': request.informationExtracted,
    if (request.informationExtractedValues.isNotEmpty)
      'reference_information_extracted_multiple':
          request.informationExtractedValues,
    if (request.width != null) 'width': request.width,
    if (request.height != null) 'height': request.height,
    if (request.size != null) 'size': request.size,
    'response_format': request.responseFormat,
  }, patches);
}
