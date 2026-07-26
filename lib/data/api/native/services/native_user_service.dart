import 'package:dio/dio.dart';

import '../../../../core/errors/app_exception.dart';
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
    final attempted = <String>[];
    try {
      return _parse(await _fetch(attempted));
    } catch (error) {
      final mapped = NetworkErrorMapper.map(error);
      throw NetworkException(
        '${mapped.message}（已尝试：${attempted.join('、')}）',
        cause: mapped,
      );
    }
  }

  /// Reads the tier from the configured endpoint, falling back to the official
  /// account host when that endpoint cannot serve `/user/*`.
  ///
  /// Any failure of the first attempt is treated as "this endpoint cannot
  /// answer" rather than a fatal error: gateways signal it with assorted status
  /// codes, HTML pages, or a plain-text notice, and the fallback is harmless
  /// when the endpoint was simply unreachable.
  Future<Map<String, Object?>> _fetch(List<String> attempted) async {
    try {
      final response = await client.get<Object?>('/user/subscription');
      attempted.add(_hostOf(response.requestOptions.uri));
      if (!_isWrongHost(response.data)) return asJsonMap(response.data);
    } on DioException catch (error) {
      attempted.add(_hostOf(error.requestOptions.uri));
    } catch (_) {
      // A parsing failure still means this endpoint cannot answer.
    }
    final fallback =
        '${NativeEndpointResolver.officialAccountBaseUrl()}/user/subscription';
    attempted.add(_hostOf(Uri.parse(fallback)));
    final response = await client.get<Object?>(fallback);
    return asJsonMap(response.data);
  }

  String _hostOf(Uri uri) => uri.host.isEmpty ? uri.toString() : uri.host;

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
