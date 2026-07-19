import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/network_error_mapper.dart';
import '../../../../domain/entities/subscription_info.dart';
import '../../common/json_helpers.dart';

class NativeSubscriptionService {
  const NativeSubscriptionService(this.client);

  final Dio client;

  Future<SubscriptionInfo> getSubscription() async {
    try {
      final response = await client.get<Object?>(
        '${AppConstants.nativeUserBaseUrl}/user/subscription',
      );
      final json = asJsonMap(response.data);
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
    } catch (error) {
      throw NetworkErrorMapper.map(error);
    }
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
