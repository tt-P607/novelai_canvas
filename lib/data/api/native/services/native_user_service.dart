import 'package:dio/dio.dart';

import '../../../../core/errors/app_exception.dart';
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

  /// Reads the tier from the configured endpoint only.
  ///
  /// There is deliberately no fallback to the official hosts: when the user
  /// configures a gateway, every request must stay on that gateway. A gateway
  /// that forwards `/user/subscription` to api.novelai.net gets the
  /// "update to the image URL" notice back, which is a gateway routing issue
  /// to fix server-side, not something to paper over by contacting NovelAI
  /// directly from the client.
  Future<SubscriptionInfo> getSubscription() async {
    try {
      final response = await client.get<Object?>('/user/subscription');
      if (_isWrongHost(response.data)) {
        throw const ConfigurationException(
          '当前接口未正确处理 /user/subscription：NovelAI 已将账户读取迁至 '
          'image.novelai.net，请让网关把该路径转发到 image 域名。',
        );
      }
      return _parse(asJsonMap(response.data));
    } catch (error) {
      throw NetworkErrorMapper.map(error);
    }
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
