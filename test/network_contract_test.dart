import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_canvas/core/constants/app_constants.dart';
import 'package:novelai_canvas/core/errors/app_exception.dart';
import 'package:novelai_canvas/core/network/api_mode_router.dart';
import 'package:novelai_canvas/core/network/backend_mode.dart';
import 'package:novelai_canvas/core/network/bearer_token_interceptor.dart';
import 'package:novelai_canvas/core/network/native_endpoint_interceptor.dart';
import 'package:novelai_canvas/core/network/native_endpoint_resolver.dart';
import 'package:novelai_canvas/core/network/network_error_mapper.dart';
import 'package:novelai_canvas/domain/entities/app_settings.dart';
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

  test('连接错误会显示实际目标主机，便于确认请求是否在客户端被拦截', () {
    final request = RequestOptions(
      path: '/ai/generate-image',
      baseUrl: 'http://gateway.example.com:31555/_api',
    );
    final mapped = NetworkErrorMapper.map(
      DioException(
        requestOptions: request,
        type: DioExceptionType.connectionError,
        error: StateError('Connection refused'),
      ),
    );

    expect(mapped.message, contains('无法连接到接口'));
    expect(mapped.message, contains('http://gateway.example.com:31555'));
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

  test('原生接口填写网关 URL 后，图片与账户请求都发往 /_api 代理路由', () async {
    const settings = AppSettings(
      onboardingCompleted: true,
      backendMode: BackendMode.native,
      endpointBaseUrl: 'https://gateway.example.com/',
    );
    final dio = Dio();
    dio.interceptors.add(
      NativeEndpointInterceptor(settingsProvider: () => settings),
    );
    final adapter = _UriInspectAdapter();
    dio.httpClientAdapter = adapter;

    await dio.post<Object?>('/ai/generate-image');
    expect(
      adapter.lastUri.toString(),
      'https://gateway.example.com/_api/ai/generate-image',
    );

    await dio.get<Object?>('/user/subscription');
    expect(
      adapter.lastUri.toString(),
      'https://gateway.example.com/_api/user/subscription',
    );
  });

  test('默认官方 URL 按 NovelAI 原生路径拆分图片与账户域名', () {
    const settings = AppSettings.initial();

    expect(
      NativeEndpointResolver.imageBaseUrl(settings),
      AppConstants.nativeBaseUrl,
    );
    expect(
      NativeEndpointResolver.accountBaseUrl(settings),
      AppConstants.nativeUserBaseUrl,
    );
  });

  test('用户改成其他 URL 后不拆分域名，并自动补全 /_api', () {
    const settings = AppSettings(
      onboardingCompleted: true,
      backendMode: BackendMode.native,
      endpointBaseUrl: 'https://gateway.example.com/',
    );

    expect(
      NativeEndpointResolver.imageBaseUrl(settings),
      'https://gateway.example.com/_api',
    );
    expect(
      NativeEndpointResolver.accountBaseUrl(settings),
      'https://gateway.example.com/_api',
    );
  });

  test('填写完整网关生成地址时会还原为网关根路由，不会重复拼接路径', () async {
    const settings = AppSettings(
      onboardingCompleted: true,
      backendMode: BackendMode.native,
      endpointBaseUrl:
          'http://gateway.example.com:31555/_api/ai/generate-image',
    );
    final dio = Dio();
    dio.interceptors.add(
      NativeEndpointInterceptor(settingsProvider: () => settings),
    );
    final adapter = _UriInspectAdapter();
    dio.httpClientAdapter = adapter;

    await dio.post<Object?>('/ai/generate-image');

    expect(
      adapter.lastUri.toString(),
      'http://gateway.example.com:31555/_api/ai/generate-image',
    );
  });

  test('填写完整 NovelAI 官方生成地址时仍使用官方域名拆分规则', () {
    const settings = AppSettings(
      onboardingCompleted: true,
      backendMode: BackendMode.native,
      endpointBaseUrl: 'https://image.novelai.net/ai/generate-image',
    );

    expect(
      NativeEndpointResolver.imageBaseUrl(settings),
      AppConstants.nativeBaseUrl,
    );
    expect(
      NativeEndpointResolver.accountBaseUrl(settings),
      AppConstants.nativeUserBaseUrl,
    );
  });

  test('用户已填写 /_api 时不会重复补全前缀', () {
    const settings = AppSettings(
      onboardingCompleted: true,
      backendMode: BackendMode.native,
      endpointBaseUrl: 'https://gateway.example.com/_api/',
    );

    expect(
      NativeEndpointResolver.imageBaseUrl(settings),
      'https://gateway.example.com/_api',
    );
  });

  test('原生接口 404 提示说明自定义 URL 会接收原始路径', () {
    final request = RequestOptions(path: '/ai/generate-image');
    final mapped = NetworkErrorMapper.map(
      DioException(
        requestOptions: request,
        response: Response(requestOptions: request, statusCode: 404),
      ),
    );

    expect(mapped.message, contains('自定义接口会接收原始 NovelAI 路径'));
    expect(mapped.message, isNot(contains('image.novelai.net')));
  });

  test('OpenAI 网关 URL 填写或省略 /v1 都只拼接一次版本路径', () async {
    for (final configuredUrl in const [
      'https://gateway.example.com',
      'https://gateway.example.com/',
      'https://gateway.example.com/v1',
      'https://gateway.example.com/v1/',
    ]) {
      final settings = AppSettings(
        onboardingCompleted: true,
        backendMode: BackendMode.gateway,
        endpointBaseUrl: configuredUrl,
      );
      final gatewayClient = Dio();
      final adapter = _UriInspectAdapter();
      gatewayClient.httpClientAdapter = adapter;
      final router = ApiModeRouter(
        nativeClient: Dio(),
        gatewayClient: gatewayClient,
        settingsProvider: () => settings,
      );

      await router.activeClient.post<Object?>('/v1/images/generations');

      expect(
        adapter.lastUri.toString(),
        'https://gateway.example.com/v1/images/generations',
        reason: '配置地址：$configuredUrl',
      );
    }
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

class _UriInspectAdapter implements HttpClientAdapter {
  Uri? lastUri;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastUri = options.uri;
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}
