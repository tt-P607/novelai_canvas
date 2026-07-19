import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../domain/entities/generated_image.dart';
import '../errors/app_exception.dart';

abstract final class ImageResponseDecoder {
  static List<GeneratedImage> decodeZip(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final images = <GeneratedImage>[];
      for (final file in archive.files) {
        if (!file.isFile) continue;
        final lowerName = file.name.toLowerCase();
        if (!lowerName.endsWith('.png') &&
            !lowerName.endsWith('.webp') &&
            !lowerName.endsWith('.jpg') &&
            !lowerName.endsWith('.jpeg')) {
          continue;
        }
        images.add(
          GeneratedImage(
            bytes: Uint8List.fromList(file.content as List<int>),
            mimeType: _mimeType(lowerName),
          ),
        );
      }
      if (images.isEmpty) {
        throw const DataParsingException('ZIP 响应中没有找到图片文件。');
      }
      return images;
    } on AppException {
      rethrow;
    } catch (error) {
      throw DataParsingException('无法解析 ZIP 图片响应。', cause: error);
    }
  }

  static List<GeneratedImage> decodeOpenAiImages(Map<String, Object?> json) {
    final data = json['data'];
    if (data is! List) {
      throw const DataParsingException('图片响应缺少 data 数组。');
    }
    final images = <GeneratedImage>[];
    for (final item in data) {
      if (item is! Map) continue;
      final revisedPrompt = item['revised_prompt']?.toString();
      final b64 = item['b64_json']?.toString();
      if (b64 != null && b64.isNotEmpty) {
        images.add(
          GeneratedImage(
            bytes: decodeBase64Image(b64),
            revisedPrompt: revisedPrompt,
          ),
        );
        continue;
      }
      final url = item['url']?.toString();
      final uri = url == null ? null : Uri.tryParse(url);
      if (uri != null) {
        images.add(GeneratedImage(url: uri, revisedPrompt: revisedPrompt));
      }
    }
    if (images.isEmpty) {
      throw const DataParsingException('图片响应中没有 url 或 b64_json。');
    }
    return images;
  }

  static GeneratedImage decodeChatMarkdown(String content) {
    final markdown = RegExp(r'!\[[^\]]*\]\(([^)]+)\)').firstMatch(content);
    final rawUrl = markdown?.group(1) ?? content.trim();
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme) {
      throw const DataParsingException('Chat 响应中没有有效图片链接。');
    }
    return GeneratedImage(url: uri);
  }

  static Uint8List decodeBase64Image(String value) {
    try {
      final payload = value.contains(',')
          ? value.substring(value.indexOf(',') + 1)
          : value;
      return base64Decode(payload);
    } catch (error) {
      throw DataParsingException('无法解析 Base64 图片。', cause: error);
    }
  }

  static String _mimeType(String name) {
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    return 'image/png';
  }
}
