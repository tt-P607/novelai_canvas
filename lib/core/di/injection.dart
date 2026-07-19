import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/local/app_preferences.dart';
import '../../data/repositories/app_settings_repository_impl.dart';
import '../../data/repositories/flutter_secure_credential_store.dart';
import '../../domain/repositories/app_settings_repository.dart';
import '../../domain/repositories/secure_credential_store.dart';
import '../../presentation/controllers/app_settings_controller.dart';
import '../network/api_inspector.dart';
import '../network/api_mode_router.dart';
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
    () => DioFactory.createNative()..interceptors.add(getIt<ApiInspector>()),
    instanceName: ServiceNames.nativeDio,
  );
  getIt.registerLazySingleton<Dio>(
    () => DioFactory.createGateway()..interceptors.add(getIt<ApiInspector>()),
    instanceName: ServiceNames.gatewayDio,
  );
  getIt.registerLazySingleton<ApiModeRouter>(
    () => ApiModeRouter(
      nativeClient: getIt(instanceName: ServiceNames.nativeDio),
      gatewayClient: getIt(instanceName: ServiceNames.gatewayDio),
      settingsProvider: () => getIt<AppSettingsController>().settings,
    ),
  );
}
