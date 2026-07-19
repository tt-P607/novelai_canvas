import 'package:dio/dio.dart';

import '../../domain/repositories/secure_credential_store.dart';
import '../errors/app_exception.dart';

class BearerTokenInterceptor extends Interceptor {
  BearerTokenInterceptor({
    required SecureCredentialStore credentialStore,
    required String credentialKey,
    required String missingCredentialMessage,
  }) : _credentialStore = credentialStore,
       _credentialKey = credentialKey,
       _missingCredentialMessage = missingCredentialMessage;

  final SecureCredentialStore _credentialStore;
  final String _credentialKey;
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

    final token = (await _credentialStore.read(_credentialKey))?.trim();
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
