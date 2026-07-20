import 'package:equatable/equatable.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/backend_mode.dart';
import 'endpoint_profile.dart';

class AppSettings extends Equatable {
  const AppSettings({
    required this.onboardingCompleted,
    required this.backendMode,
    required this.endpointBaseUrl,
  });

  const AppSettings.initial()
    : onboardingCompleted = false,
      backendMode = BackendMode.native,
      endpointBaseUrl = AppConstants.nativeBaseUrl;

  final bool onboardingCompleted;
  final BackendMode backendMode;
  final String endpointBaseUrl;

  String get effectiveBaseUrl {
    final value = endpointBaseUrl.trim();
    if (value.isNotEmpty) return value;
    return backendMode == BackendMode.native ? AppConstants.nativeBaseUrl : '';
  }

  Map<String, Object?> toJson() => {
    'onboarding_completed': onboardingCompleted,
    'backend_mode': backendMode.name,
    'endpoint_base_url': endpointBaseUrl.trim(),
  };

  factory AppSettings.fromJson(Map<String, Object?> json) {
    final backendMode = BackendMode.values.firstWhere(
      (mode) => mode.name == json['backend_mode']?.toString(),
      orElse: () => BackendMode.native,
    );
    final storedUrl =
        json['endpoint_base_url']?.toString() ??
        json['gateway_base_url']?.toString() ??
        '';
    final normalizedUrl = storedUrl.trim();
    return AppSettings(
      onboardingCompleted: json['onboarding_completed'] == true,
      backendMode: backendMode,
      endpointBaseUrl:
          normalizedUrl.isEmpty && backendMode == BackendMode.native
          ? AppConstants.nativeBaseUrl
          : normalizedUrl,
    );
  }

  EndpointProfile get activeEndpoint => EndpointProfile(
    mode: backendMode,
    baseUrl: effectiveBaseUrl,
    credentialId: AppConstants.imageApiCredentialKey,
  );

  AppSettings copyWith({
    bool? onboardingCompleted,
    BackendMode? backendMode,
    String? endpointBaseUrl,
  }) {
    return AppSettings(
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      backendMode: backendMode ?? this.backendMode,
      endpointBaseUrl: endpointBaseUrl ?? this.endpointBaseUrl,
    );
  }

  @override
  List<Object?> get props => [
    onboardingCompleted,
    backendMode,
    endpointBaseUrl,
  ];
}
