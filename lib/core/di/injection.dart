import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/api/danbooru/danbooru_service.dart';
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
import '../../data/api/llm/llm_chat_service.dart';
import '../../data/api/native/services/native_user_service.dart';
import '../../data/datasources/local/app_preferences.dart';
import '../../data/datasources/local/generation_database.dart';
import '../../data/datasources/local/llm_assistant_preferences.dart';
import '../../data/repositories/app_settings_repository_impl.dart';
import '../../data/repositories/flutter_secure_credential_store.dart';
import '../../data/repositories/generation_history_repository_impl.dart';
import '../../data/repositories/generation_repository_impl.dart';
import '../../data/repositories/image_tools_repository_impl.dart';
import '../../data/repositories/llm_assistant_settings_repository_impl.dart';
import '../../data/repositories/prompt_assistant_repository_impl.dart';
import '../../domain/repositories/app_settings_repository.dart';
import '../../domain/repositories/generation_history_repository.dart';
import '../../domain/repositories/generation_repository.dart';
import '../../domain/repositories/image_tools_repository.dart';
import '../../domain/repositories/llm_assistant_settings_repository.dart';
import '../../domain/repositories/prompt_assistant_repository.dart';
import '../../domain/repositories/secure_credential_store.dart';
import '../../presentation/controllers/app_settings_controller.dart';
import '../../presentation/controllers/data_management_controller.dart';
import '../../presentation/controllers/generation_controller.dart';
import '../../presentation/controllers/history_controller.dart';
import '../../presentation/controllers/image_tools_controller.dart';
import '../../presentation/controllers/llm_assistant_settings_controller.dart';
import '../../presentation/controllers/prompt_assistant_controller.dart';
import '../backup/app_backup_service.dart';
import '../constants/app_constants.dart';
import '../network/api_inspector.dart';
import '../network/api_mode_router.dart';
import '../network/backend_connection_service.dart';
import '../network/bearer_token_interceptor.dart';
import '../network/dio_factory.dart';
import '../queue/generation_queue.dart';
import '../storage/generation_image_store.dart';

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
  getIt.registerLazySingleton<LlmAssistantPreferences>(
    () => LlmAssistantPreferences(getIt()),
  );

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

  getIt.registerLazySingleton<LlmAssistantSettingsRepository>(
    () => LlmAssistantSettingsRepositoryImpl(getIt()),
  );
  final llmSettings = await getIt<LlmAssistantSettingsRepository>().load();
  getIt.registerSingleton<LlmAssistantSettingsController>(
    LlmAssistantSettingsController(
      repository: getIt(),
      credentialStore: getIt(),
      initialSettings: llmSettings,
    ),
  );

  getIt.registerLazySingleton(GenerationDatabase.new);
  getIt.registerLazySingleton(GenerationImageStore.new);
  getIt.registerLazySingleton<GenerationHistoryRepository>(
    () => GenerationHistoryRepositoryImpl(getIt()),
  );
  await getIt<GenerationHistoryRepository>().initialize();

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
  getIt.registerLazySingleton(() => LlmChatService(Dio()));
  getIt.registerLazySingleton(() => DanbooruService(Dio()));

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

  getIt.registerLazySingleton<GenerationRepository>(
    () => GenerationRepositoryImpl(
      nativeTextToImageService: getIt(),
      nativeImageToImageService: getIt(),
      nativeInpaintService: getIt(),
      nativeStreamService: getIt(),
      nativeEncodeVibeService: getIt(),
      gatewayGenerationService: getIt(),
      gatewayChatService: getIt(),
      gatewayVibeTransferService: getIt(),
      gatewayImageToImageService: getIt(),
      gatewayInpaintService: getIt(),
    ),
  );
  getIt.registerLazySingleton<ImageToolsRepository>(
    () => ImageToolsRepositoryImpl(
      backendModeProvider: () =>
          getIt<AppSettingsController>().settings.backendMode,
      nativeUpscaleService: getIt(),
      nativeTagSuggestionService: getIt(),
      nativeDirectorService: getIt(),
      gatewayUpscaleService: getIt(),
      gatewayTagSuggestionService: getIt(),
      gatewayDeclutterService: getIt(),
      gatewayBackgroundRemovalService: getIt(),
      gatewayLineartService: getIt(),
      gatewaySketchService: getIt(),
      gatewayColorizeService: getIt(),
      gatewayEmotionService: getIt(),
    ),
  );
  getIt.registerLazySingleton<PromptAssistantRepository>(
    () => PromptAssistantRepositoryImpl(
      llmService: getIt(),
      danbooruService: getIt(),
      credentialStore: getIt(),
    ),
  );
  getIt.registerLazySingleton(
    () => GenerationQueue(
      generationRepository: getIt(),
      historyRepository: getIt(),
      imageStore: getIt(),
    ),
  );
  await getIt<GenerationQueue>().initialize();
  getIt.registerLazySingleton(
    () => GenerationController(
      queue: getIt(),
      historyRepository: getIt(),
      backendModeProvider: () =>
          getIt<AppSettingsController>().settings.backendMode,
    ),
  );
  getIt.registerLazySingleton(
    () => HistoryController(repository: getIt(), queue: getIt()),
  );
  getIt.registerLazySingleton(
    () => ImageToolsController(repository: getIt(), imageStore: getIt()),
  );
  getIt.registerLazySingleton(
    () => AppBackupService(
      appSettingsRepository: getIt(),
      llmSettingsRepository: getIt(),
      historyRepository: getIt(),
    ),
  );
  getIt.registerLazySingleton(
    () => DataManagementController(
      backupService: getIt(),
      credentialStore: getIt(),
      appSettingsController: getIt(),
      llmSettingsController: getIt(),
      historyController: getIt(),
    ),
  );
  getIt.registerLazySingleton(
    () => PromptAssistantController(
      repository: getIt(),
      settingsController: getIt(),
    ),
  );
  await getIt<HistoryController>().load();
}
