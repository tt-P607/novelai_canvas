import 'package:dio/dio.dart';

import '../../../../core/network/native_endpoint_resolver.dart';
import '../../../../core/network/network_error_mapper.dart';
import '../../../../domain/entities/subscription_info.dart';
import '../../common/json_helpers.dart';

/// NovelAI answers account requests aimed at the wrong host with this notice.
/// It may arrive as a bare string, as a JSON field, or inside an HTML page, and
/// often carries a success status, so the body has to be inspected directly.
const _wrongHostNotice = 'update to the image url';

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

  /// Reads the tier from the configured endpoint, falling back to the official
  /// account host when that endpoint cannot serve `/user/*`.
  ///
  /// Any failure of the first attempt is treated as "this endpoint cannot
  /// answer" rather than a fatal error: gateways signal it with assorted status
  /// codes, HTML pages, or a plain-text notice, and the fallback is harmless
  /// when the endpoint was simply unreachable.
  Future<Map<String, Object?>> _fetch() async {
    try {
      final data = (await client.get<Object?>('/user/subscription')).data;
      if (!_isWrongHost(data)) return asJsonMap(data);
    } catch (_) {
      // Fall through to the official account host.
    }
    final response = await client.get<Object?>(
      '${NativeEndpointResolver.officialAccountBaseUrl()}/user/subscription',
    );
    return asJsonMap(response.data);
  }

  bool _isWrongHost(Object? data) {
    if (data is Map && data.containsKey('tier')) return false;
    return data.toString().toLowerCase().contains(_wrongHostNotice);
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
