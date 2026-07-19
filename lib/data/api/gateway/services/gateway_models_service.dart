import 'package:dio/dio.dart';

import '../../../../core/network/network_error_mapper.dart';
import '../../../../domain/entities/model_info.dart';
import '../../common/json_helpers.dart';

class GatewayModelsService {
  const GatewayModelsService(this.client);
  final Dio client;

  Future<List<ModelInfo>> listModels() async {
    try {
      final response = await client.get<Object?>('/v1/models');
      final json = asJsonMap(response.data);
      final data = json['data'] as List? ?? const [];
      return data.whereType<Map>().map((raw) {
        final item = Map<String, Object?>.from(raw);
        return ModelInfo(
          id: item['id']?.toString() ?? '',
          object: item['object']?.toString(),
          created: (item['created'] as num?)?.toInt(),
          ownedBy: item['owned_by']?.toString(),
        );
      }).toList();
    } catch (error) {
      throw NetworkErrorMapper.map(error);
    }
  }
}
