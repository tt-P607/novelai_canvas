import 'package:dio/dio.dart';

import '../../../../core/network/network_error_mapper.dart';
import '../../../../domain/entities/tag_suggestion.dart';
import '../../common/json_helpers.dart';
import '../dto/gateway_tag_suggestion_request_dto.dart';

class GatewayTagSuggestionService {
  GatewayTagSuggestionService(
    this.client, {
    GatewayTagSuggestionRequestBuilder? builder,
  }) : builder = builder ?? const GatewayTagSuggestionRequestBuilder();
  final Dio client;
  final GatewayTagSuggestionRequestBuilder builder;

  Future<List<TagSuggestion>> suggest(
    GatewayTagSuggestionRequestDto request,
  ) async {
    try {
      final response = await client.post<Object?>(
        '/v1/images/suggest-tags',
        data: builder.build(request),
      );
      final json = asJsonMap(response.data);
      return (json['tags'] as List? ?? const []).whereType<Map>().map((raw) {
        final item = Map<String, Object?>.from(raw);
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
