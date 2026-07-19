import 'package:dio/dio.dart';

import '../../domain/entities/backend_capabilities.dart';
import '../../domain/entities/model_info.dart';
import '../../data/api/gateway/services/gateway_models_service.dart';
import '../errors/app_exception.dart';
import 'api_mode_router.dart';
import 'backend_mode.dart';
import 'network_error_mapper.dart';

class BackendProbeResult {
  const BackendProbeResult({
    required this.mode,
    required this.reachable,
    required this.capabilities,
    this.models = const [],
    this.message,
  });

  final BackendMode mode;
  final bool reachable;
  final BackendCapabilities capabilities;
  final List<ModelInfo> models;
  final String? message;
}

class BackendConnectionService {
  const BackendConnectionService(this.router);
  final ApiModeRouter router;

  Future<BackendProbeResult> probe(BackendMode mode) async {
    final capabilities = switch (mode) {
      BackendMode.native => const BackendCapabilities.native(),
      BackendMode.gateway => const BackendCapabilities.gateway(),
    };
    try {
      if (mode == BackendMode.gateway) {
        final models = await GatewayModelsService(
          router.clientFor(mode),
        ).listModels();
        return BackendProbeResult(
          mode: mode,
          reachable: true,
          capabilities: capabilities,
          models: models,
        );
      }
      final client = router.clientFor(mode);
      await client.get<Object?>('/user/data');
      return BackendProbeResult(
        mode: mode,
        reachable: true,
        capabilities: capabilities,
      );
    } on AppException catch (error) {
      return BackendProbeResult(
        mode: mode,
        reachable: false,
        capabilities: capabilities,
        message: error.message,
      );
    } on DioException catch (error) {
      return BackendProbeResult(
        mode: mode,
        reachable: false,
        capabilities: capabilities,
        message: NetworkErrorMapper.map(error).message,
      );
    }
  }
}
