import 'package:dio/dio.dart';

import '../../../domain/entities/prompt_assistant.dart';

class DanbooruService {
  DanbooruService(this._dio);

  static const defaultBaseUrls = [
    'https://sakizuki-danboorusearch.hf.space',
    'https://sakizuki-danboorusearchonline.ms.show',
  ];

  final Dio _dio;

  Future<List<DanbooruTag>> search({
    required String query,
    required bool showNsfw,
    String customBaseUrl = '',
    int limit = 20,
  }) async {
    final data = await _post('/api/search', {
      'query': query,
      'top_k': 5,
      'limit': limit,
      'show_nsfw': showNsfw,
    }, customBaseUrl);
    if (data is! Map || data['results'] is! List) return const [];
    return (data['results'] as List)
        .whereType<Map>()
        .map((item) => _parseSearch(Map<String, Object?>.from(item)))
        .where((tag) => tag.tag.isNotEmpty)
        .toList();
  }

  Future<List<DanbooruTag>> related({
    required List<String> tags,
    required bool showNsfw,
    String customBaseUrl = '',
    int limit = 20,
  }) async {
    if (tags.isEmpty) return const [];
    final data = await _post('/api/related', {
      'tags': tags,
      'limit': limit,
      'show_nsfw': showNsfw,
    }, customBaseUrl);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((item) => _parseRelated(Map<String, Object?>.from(item)))
        .where((tag) => tag.tag.isNotEmpty)
        .toList();
  }

  Future<Object?> _post(
    String path,
    Map<String, Object?> body,
    String customBaseUrl,
  ) async {
    final bases = customBaseUrl.trim().isEmpty
        ? defaultBaseUrls
        : [customBaseUrl.trim()];
    Object? lastError;
    for (final value in bases) {
      final base = value.replaceAll(RegExp(r'/+$'), '');
      try {
        final response = await _dio.post<Object?>(
          '$base$path',
          data: body,
          options: Options(
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            sendTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
          ),
        );
        return response.data;
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError('Danbooru 校准服务不可用：$lastError');
  }

  DanbooruTag _parseSearch(Map<String, Object?> json) => DanbooruTag(
    tag: json['tag']?.toString() ?? '',
    cnName: json['cn_name']?.toString() ?? '',
    category: json['category']?.toString() ?? '',
    nsfw: json['nsfw']?.toString() ?? '',
    count: _int(json['count']),
    score: _double(json['final_score']),
    wiki: json['wiki']?.toString() ?? '',
    origin: 'search',
  );

  DanbooruTag _parseRelated(Map<String, Object?> json) => DanbooruTag(
    tag: json['tag']?.toString() ?? '',
    cnName: json['cn_name']?.toString() ?? '',
    category: json['category']?.toString() ?? '',
    nsfw: json['nsfw']?.toString() ?? '',
    count: _int(json['post_count']),
    score: _double(json['cooc_score']),
    wiki: json['wiki']?.toString() ?? '',
    sources: json['sources'] is List
        ? (json['sources'] as List).map((item) => item.toString()).toList()
        : const [],
    origin: 'related',
  );

  int _int(Object? value) => switch (value) {
    int number => number,
    num number => number.toInt(),
    _ => int.tryParse(value?.toString() ?? '') ?? 0,
  };

  double _double(Object? value) => switch (value) {
    double number => number,
    num number => number.toDouble(),
    _ => double.tryParse(value?.toString() ?? '') ?? 0,
  };
}
