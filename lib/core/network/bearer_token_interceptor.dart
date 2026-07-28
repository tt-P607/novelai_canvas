import 'package:dio/dio.dart';

import '../../domain/repositories/secure_credential_store.dart';
import '../errors/app_exception.dart';

class BearerTokenInterceptor extends Interceptor {
  BearerTokenInterceptor({
    required SecureCredentialStore credentialStore,
    required String credentialKey,
    required String missingCredentialMessage,
  }) : this.resolver(
         credentialStore: credentialStore,
         credentialKeyResolver: () => credentialKey,
         missingCredentialMessage: missingCredentialMessage,
       );

  /// Multi-key variant: the active key is resolved per request, so a single
  /// Dio instance can serve both backends after the user switches modes.
  BearerTokenInterceptor.resolver({
    required SecureCredentialStore credentialStore,
    required String Function() credentialKeyResolver,
    required String missingCredentialMessage,
  }) : _credentialStore = credentialStore,
       _credentialKeyResolver = credentialKeyResolver,
       _missingCredentialMessage = missingCredentialMessage;

  final SecureCredentialStore _credentialStore;
  final String Function() _credentialKeyResolver;
  final String _missingCredentialMessage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuthenticationExtraKey] == true) {
      handler.next(options);
      return;
    }

    final token = (await _credentialStore.read(
      _credentialKeyResolver(),
    ))?.trim();
    if (token == null || token.isEmpty) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: ConfigurationException(_missingCredentialMessage),
        ),
      );
      return;
    }

    options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }
}

const skipAuthenticationExtraKey = 'skipAuthentication';
