import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../domain/entities/advanced_generation.dart';

/// Helper utility for parsing .naiv4vibe and .naiv4vibebundle files,
/// as well as NAI JSON formats containing vibe encodings and thumbnails.
class VibeFileParser {
  const VibeFileParser._();

  /// Parses bytes from a .naiv4vibe or JSON file into [VibeReference]s.
  static Future<List<VibeReference>> parseBytes(
    Uint8List bytes, {
    String? defaultName,
  }) async {
    return compute(_parseIsolate, {
      'bytes': bytes,
      'defaultName': defaultName ?? 'Vibe Reference',
    });
  }

  static List<VibeReference> _parseIsolate(Map<String, dynamic> args) {
    final bytes = args['bytes'] as Uint8List;
    final defaultName = args['defaultName'] as String;

    try {
      final jsonString = utf8.decode(bytes);
      final dynamic jsonData = jsonDecode(jsonString);

      if (jsonData is Map<String, dynamic>) {
        // Multi-vibe bundle format
        if (jsonData.containsKey('vibes') && jsonData['vibes'] is List) {
          final list = jsonData['vibes'] as List;
          final results = <VibeReference>[];
          for (var i = 0; i < list.length; i++) {
            final item = list[i];
            if (item is Map<String, dynamic>) {
              final ref = _parseSingleVibeMap(
                item,
                fallbackName: '$defaultName ${i + 1}',
              );
              if (ref != null) results.add(ref);
            }
          }
          return results;
        }

        // Single vibe format
        final ref = _parseSingleVibeMap(jsonData, fallbackName: defaultName);
        if (ref != null) return [ref];
      }
    } catch (_) {
      // Not a valid JSON structure, treat as raw binary pre-encoded vibe data
    }

    final encoded = base64Encode(bytes);
    return [
      VibeReference(
        encodedData: encoded,
        displayName: defaultName,
        strength: 0.5,
        informationExtracted: 1.0,
        encodingCache: {1.0: encoded},
      ),
    ];
  }

  static VibeReference? _parseSingleVibeMap(
    Map<String, dynamic> map, {
    required String fallbackName,
  }) {
    final name = map['name']?.toString() ?? fallbackName;
    final importInfo = map['importInfo'] as Map<String, dynamic>?;

    double strength = 0.5;
    double infoExtracted = 1.0;

    if (importInfo != null) {
      if (importInfo['strength'] is num) {
        strength = (importInfo['strength'] as num).toDouble();
      }
      if (importInfo['information_extracted'] is num) {
        infoExtracted = (importInfo['information_extracted'] as num).toDouble();
      }
    }

    final cache = _extractEncodingCache(map, fallbackIe: infoExtracted);
    final sourceImageBase64 = _extractBase64(map['image']);
    final thumbnailBase64 =
        _extractBase64(map['thumbnail']) ?? sourceImageBase64;

    if (cache.isEmpty && sourceImageBase64 == null) return null;

    final activeKey = _ieKey(infoExtracted);
    final activeEncoding =
        cache[activeKey] ?? (cache.length == 1 ? cache.values.single : null);
    if (activeEncoding != null && !cache.containsKey(activeKey)) {
      cache[activeKey] = activeEncoding;
    }

    return VibeReference(
      sourceImageBase64: sourceImageBase64,
      encodedData: activeEncoding,
      displayName: name,
      thumbnailBase64: thumbnailBase64,
      strength: strength,
      informationExtracted: infoExtracted,
      encodingCache: cache,
      enabled: activeEncoding != null,
    );
  }

  static Map<double, String> _extractEncodingCache(
    Map<String, dynamic> map, {
    required double fallbackIe,
  }) {
    final cache = <double, String>{};
    final direct = map['vibeEncoding'] ?? map['encoding'];
    if (direct is String && direct.isNotEmpty) {
      cache[_ieKey(fallbackIe)] = direct;
    }

    final encodings = map['encodings'];
    if (encodings is! Map) return cache;
    for (final modelEntry in encodings.values.whereType<Map>()) {
      for (final encodingEntry in modelEntry.entries) {
        final value = encodingEntry.value;
        if (value is! Map || value['encoding'] is! String) continue;
        final encoding = value['encoding'] as String;
        if (encoding.isEmpty) continue;
        final params = value['params'];
        final paramsIe = params is Map
            ? (params['information_extracted'] as num?)?.toDouble()
            : null;
        final keyIe = double.tryParse(encodingEntry.key.toString());
        cache[_ieKey(paramsIe ?? keyIe ?? fallbackIe)] = encoding;
      }
    }
    return cache;
  }

  static String? _extractBase64(Object? value) {
    final data = value?.toString();
    if (data == null || data.isEmpty) return null;
    if (!data.startsWith('data:')) return data;
    final comma = data.indexOf(',');
    return comma == -1 ? null : data.substring(comma + 1);
  }

  static double _ieKey(double value) => double.parse(value.toStringAsFixed(2));
}
