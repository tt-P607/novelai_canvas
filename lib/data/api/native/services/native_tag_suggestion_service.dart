import 'package:dio/dio.dart';

import '../../../../core/network/network_error_mapper.dart';
import '../../../../domain/entities/tag_suggestion.dart';
import '../../common/json_helpers.dart';
import '../dto/native_tag_suggestion_request_dto.dart';

class NativeTagSuggestionService {
  NativeTagSuggestionService(
    this.client, {
    NativeTagSuggestionRequestBuilder? builder,
  }) : builder = builder ?? const NativeTagSuggestionRequestBuilder();

  final Dio client;
  final NativeTagSuggestionRequestBuilder builder;

  Future<List<TagSuggestion>> suggest(
    NativeTagSuggestionRequestDto request,
  ) async {
    try {
      final response = await client.get<Object?>(
        '/ai/annotate-image',
        queryParameters: builder.build(request),
      );
      final json = asJsonMap(response.data);
      final tags = json['tags'] as List? ?? const [];
      return tags.whereType<Map>().map((tag) {
        final item = Map<String, Object?>.from(tag);
        return TagSuggestion(
          tag: item['tag']?.toString() ?? '',
          count: (item['count'] as num?)?.toInt() ?? 0,
          confidence: (item['confidence'] as num?)?.toDouble() ?? 0,
        );
      }).toList();
    } catch (error) {
      throw NetworkErrorMapper.map(error);
    }
  }
}
