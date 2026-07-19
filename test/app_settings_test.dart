import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_canvas/core/network/backend_mode.dart';
import 'package:novelai_canvas/domain/entities/app_settings.dart';

void main() {
  test('initial settings use native backend and require onboarding', () {
    const settings = AppSettings.initial();

    expect(settings.onboardingCompleted, isFalse);
    expect(settings.backendMode, BackendMode.native);
    expect(settings.gatewayBaseUrl, isEmpty);
    expect(settings.activeEndpoint.mode, BackendMode.native);
  });

  test('gateway endpoint follows configured base URL', () {
    final settings = const AppSettings.initial().copyWith(
      backendMode: BackendMode.gateway,
      gatewayBaseUrl: 'https://gateway.example.com',
    );

    expect(settings.activeEndpoint.mode, BackendMode.gateway);
    expect(settings.activeEndpoint.baseUrl, 'https://gateway.example.com');
  });
}
