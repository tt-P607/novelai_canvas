import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_canvas/core/errors/app_exception.dart';
import 'package:novelai_canvas/core/network/bearer_token_interceptor.dart';
import 'package:novelai_canvas/core/network/network_error_mapper.dart';
import 'package:novelai_canvas/domain/repositories/secure_credential_store.dart';

class _MemoryCredentialStore implements SecureCredentialStore {
  String? value;
  @override
  Future<void> clear() async => value = null;
  @override
  Future<void> delete(String key) async => value = null;
  @override
  Future<String?> read(String key) async => value;
  @override
  Future<void> write({required String key, required String value}) async {
    this.value = value;
  }
}

void main() {
  test('Bearer 拦截器从安全存储动态注入凭据', () async {
    final store = _MemoryCredentialStore()..value = 'pst-test';
    final dio = Dio();
    dio.interceptors.add(
      BearerTokenInterceptor(
        credentialStore: store,
        credentialKey: 'token',
        missingCredentialMessage: 'missing',
      ),
    );
    dio.httpClientAdapter = _InspectAdapter();

    final response = await dio.get<Object?>('https://example.com');
    expect(response.data, 'Bearer pst-test');
  });

  test('错误映射识别认证、余额与队列状态', () {
    final request = RequestOptions(path: '/test');
    final auth = NetworkErrorMapper.map(
      DioException(
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: 401,
          data: {
            'error': {'message': 'bad token'},
          },
        ),
      ),
    );
    final balance = NetworkErrorMapper.map(
      DioException(
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: 402,
          data: {'detail': 'insufficient'},
        ),
      ),
    );

    expect(auth, isA<AuthenticationException>());
    expect(auth.message, contains('bad token'));
    expect(balance.message, contains('Anlas'));
  });
}

class _InspectAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    options.headers['Authorization']?.toString() ?? '',
    200,
  );

  @override
  void close({bool force = false}) {}
}
