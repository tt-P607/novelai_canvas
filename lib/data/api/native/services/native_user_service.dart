import 'package:dio/dio.dart';

import '../../../../core/network/native_endpoint_resolver.dart';
import '../../../../core/network/network_error_mapper.dart';
import '../../../../domain/entities/subscription_info.dart';
import '../../common/json_helpers.dart';

/// NovelAI answers account requests aimed at the image host with this notice
/// instead of an error status, so it has to be detected from the payload.
const _wrongHostNotice = 'update to the image URL';

class NativeSubscriptionService {
  const NativeSubscriptionService(this.client);

  final Dio client;

  Future<SubscriptionInfo> getSubscription() async {
    try {
      return _parse(await _fetch());
    } catch (error) {
      throw NetworkErrorMapper.map(error);
    }
  }

  /// Gateways that proxy only image.novelai.net cannot serve `/user/*`.
  /// Retrying against the official account host keeps the tier readable
  /// without requiring every gateway to implement account routes.
  Future<Map<String, Object?>> _fetch() async {
    try {
      final json = asJsonMap(
        (await client.get<Object?>('/user/subscription')).data,
      );
      if (!_isWrongHostResponse(json)) return json;
    } on DioException catch (error) {
      if (error.response?.statusCode != 404) rethrow;
    }
    final response = await client.get<Object?>(
      '${NativeEndpointResolver.officialAccountBaseUrl()}/user/subscription',
    );
    return asJsonMap(response.data);
  }

  bool _isWrongHostResponse(Map<String, Object?> json) {
    if (json.containsKey('tier')) return false;
    return json.values.any(
      (value) => value is String && value.contains(_wrongHostNotice),
    );
  }

  SubscriptionInfo _parse(Map<String, Object?> json) {
    final expires = (json['expiresAt'] as num?)?.toInt();
    return SubscriptionInfo(
      tier: (json['tier'] as num?)?.toInt() ?? 0,
      active: json['active'] == true,
      expiresAt: expires == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expires * 1000),
      perks: json['perks'] is Map
          ? Map<String, Object?>.from(json['perks']! as Map)
          : const {},
      trainingStepsLeft: json['trainingStepsLeft'] is Map
          ? Map<String, Object?>.from(json['trainingStepsLeft']! as Map)
          : const {},
      raw: json,
    );
  }
}

class NativeUserDataService {
  const NativeUserDataService(this.client);

  final Dio client;

  Future<Map<String, Object?>> getUserData() async {
    try {
      final response = await client.get<Object?>('/user/data');
      return asJsonMap(response.data);
    } catch (error) {
      throw NetworkErrorMapper.map(error);
    }
  }
}
