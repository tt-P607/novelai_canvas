import 'package:equatable/equatable.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/backend_mode.dart';
import 'endpoint_profile.dart';

class AppSettings extends Equatable {
  const AppSettings({
    required this.onboardingCompleted,
    required this.backendMode,
    required this.gatewayBaseUrl,
  });

  const AppSettings.initial()
    : onboardingCompleted = false,
      backendMode = BackendMode.native,
      gatewayBaseUrl = '';

  final bool onboardingCompleted;
  final BackendMode backendMode;
  final String gatewayBaseUrl;

  EndpointProfile get activeEndpoint => switch (backendMode) {
    BackendMode.native => const EndpointProfile(
      mode: BackendMode.native,
      baseUrl: AppConstants.nativeBaseUrl,
      credentialId: AppConstants.novelAiCredentialKey,
    ),
    BackendMode.gateway => EndpointProfile(
      mode: BackendMode.gateway,
      baseUrl: gatewayBaseUrl,
      credentialId: AppConstants.gatewayCredentialKey,
    ),
  };

  AppSettings copyWith({
    bool? onboardingCompleted,
    BackendMode? backendMode,
    String? gatewayBaseUrl,
  }) {
    return AppSettings(
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      backendMode: backendMode ?? this.backendMode,
      gatewayBaseUrl: gatewayBaseUrl ?? this.gatewayBaseUrl,
    );
  }

  @override
  List<Object?> get props => [onboardingCompleted, backendMode, gatewayBaseUrl];
}
