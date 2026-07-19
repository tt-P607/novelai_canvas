import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/api/gateway/services/gateway_chat_service.dart';
import '../../data/api/gateway/services/gateway_director_services.dart';
import '../../data/api/gateway/services/gateway_edits_service.dart';
import '../../data/api/gateway/services/gateway_generation_service.dart';
import '../../data/api/gateway/services/gateway_image_to_image_service.dart';
import '../../data/api/gateway/services/gateway_inpaint_service.dart';
import '../../data/api/gateway/services/gateway_models_service.dart';
import '../../data/api/gateway/services/gateway_tag_suggestion_service.dart';
import '../../data/api/gateway/services/gateway_upscale_service.dart';
import '../../data/api/gateway/services/gateway_vibe_transfer_service.dart';
import '../../data/api/native/services/native_director_service.dart';
import '../../data/api/native/services/native_encode_vibe_service.dart';
import '../../data/api/native/services/native_image_to_image_service.dart';
import '../../data/api/native/services/native_inpaint_service.dart';
import '../../data/api/native/services/native_stream_service.dart';
import '../../data/api/native/services/native_tag_suggestion_service.dart';
import '../../data/api/native/services/native_text_to_image_service.dart';
import '../../data/api/native/services/native_upscale_service.dart';
import '../../data/api/native/services/native_user_service.dart';
import '../../data/datasources/local/app_preferences.dart';
import '../../data/repositories/app_settings_repository_impl.dart';
import '../../data/repositories/flutter_secure_credential_store.dart';
import '../../domain/repositories/app_settings_repository.dart';
import '../../domain/repositories/secure_credential_store.dart';
import '../../presentation/controllers/app_settings_controller.dart';
import '../constants/app_constants.dart';
import '../network/api_inspector.dart';
import '../network/api_mode_router.dart';
import '../network/backend_connection_service.dart';
import '../network/bearer_token_interceptor.dart';
import '../network/dio_factory.dart';

final getIt = GetIt.instance;

abstract final class ServiceNames {
  static const nativeDio = 'nativeDio';
  static const gatewayDio = 'gatewayDio';
}

Future<void> configureDependencies() async {
  if (getIt.isRegistered<AppSettingsController>()) return;

  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);
  getIt.registerLazySingleton<AppPreferences>(() => AppPreferences(getIt()));

  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  getIt.registerSingleton<FlutterSecureStorage>(secureStorage);
  getIt.registerLazySingleton<SecureCredentialStore>(
    () => FlutterSecureCredentialStore(getIt()),
  );

  getIt.registerLazySingleton<AppSettingsRepository>(
    () => AppSettingsRepositoryImpl(getIt()),
  );
  final settings = await getIt<AppSettingsRepository>().load();
  getIt.registerSingleton<AppSettingsController>(
    AppSettingsController(getIt(), settings),
  );

  getIt.registerLazySingleton<ApiInspector>(ApiInspector.new);
  getIt.registerLazySingleton<Dio>(
    () => DioFactory.createNative()
      ..interceptors.add(
        BearerTokenInterceptor(
          credentialStore: getIt(),
          credentialKey: AppConstants.novelAiCredentialKey,
          missingCredentialMessage: '请先在设置中填写 NovelAI Token。',
        ),
      )
      ..interceptors.add(getIt<ApiInspector>()),
    instanceName: ServiceNames.nativeDio,
  );
  getIt.registerLazySingleton<Dio>(
    () => DioFactory.createGateway()
      ..interceptors.add(
        BearerTokenInterceptor(
          credentialStore: getIt(),
          credentialKey: AppConstants.gatewayCredentialKey,
          missingCredentialMessage: '请先在设置中填写网关 API Key。',
        ),
      )
      ..interceptors.add(getIt<ApiInspector>()),
    instanceName: ServiceNames.gatewayDio,
  );
  getIt.registerLazySingleton<ApiModeRouter>(
    () => ApiModeRouter(
      nativeClient: getIt(instanceName: ServiceNames.nativeDio),
      gatewayClient: getIt(instanceName: ServiceNames.gatewayDio),
      settingsProvider: () => getIt<AppSettingsController>().settings,
    ),
  );

  final nativeDio = getIt<Dio>(instanceName: ServiceNames.nativeDio);
  final gatewayDio = getIt<Dio>(instanceName: ServiceNames.gatewayDio);
  getIt.registerLazySingleton(() => BackendConnectionService(getIt()));

  getIt.registerLazySingleton(() => NativeTextToImageService(nativeDio));
  getIt.registerLazySingleton(() => NativeImageToImageService(nativeDio));
  getIt.registerLazySingleton(() => NativeInpaintService(nativeDio));
  getIt.registerLazySingleton(() => NativeStreamService(nativeDio));
  getIt.registerLazySingleton(() => NativeEncodeVibeService(nativeDio));
  getIt.registerLazySingleton(() => NativeUpscaleService(nativeDio));
  getIt.registerLazySingleton(() => NativeTagSuggestionService(nativeDio));
  getIt.registerLazySingleton(() => NativeDirectorService(nativeDio));
  getIt.registerLazySingleton(() => NativeSubscriptionService(nativeDio));
  getIt.registerLazySingleton(() => NativeUserDataService(nativeDio));

  getIt.registerLazySingleton(() => GatewayModelsService(gatewayDio));
  getIt.registerLazySingleton(() => GatewayChatService(gatewayDio));
  getIt.registerLazySingleton(() => GatewayGenerationService(gatewayDio));
  getIt.registerLazySingleton(() => GatewayImageToImageService(gatewayDio));
  getIt.registerLazySingleton(() => GatewayInpaintService(gatewayDio));
  getIt.registerLazySingleton(() => GatewayEditsService(gatewayDio));
  getIt.registerLazySingleton(() => GatewayVibeTransferService(gatewayDio));
  getIt.registerLazySingleton(() => GatewayUpscaleService(gatewayDio));
  getIt.registerLazySingleton(() => GatewayTagSuggestionService(gatewayDio));
  getIt.registerLazySingleton(() => GatewayDeclutterService(gatewayDio));
  getIt.registerLazySingleton(
    () => GatewayBackgroundRemovalService(gatewayDio),
  );
  getIt.registerLazySingleton(() => GatewayLineartService(gatewayDio));
  getIt.registerLazySingleton(() => GatewaySketchService(gatewayDio));
  getIt.registerLazySingleton(() => GatewayColorizeService(gatewayDio));
  getIt.registerLazySingleton(() => GatewayEmotionService(gatewayDio));
}
