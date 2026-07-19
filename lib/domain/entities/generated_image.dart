import 'dart:typed_data';

import 'package:equatable/equatable.dart';

class GeneratedImage extends Equatable {
  const GeneratedImage({
    this.bytes,
    this.url,
    this.mimeType = 'image/png',
    this.revisedPrompt,
  }) : assert(bytes != null || url != null);

  final Uint8List? bytes;
  final Uri? url;
  final String mimeType;
  final String? revisedPrompt;

  bool get isInline => bytes != null;

  @override
  List<Object?> get props => [bytes, url, mimeType, revisedPrompt];
}
