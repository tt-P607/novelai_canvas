import 'package:equatable/equatable.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/backend_mode.dart';
import 'endpoint_profile.dart';

class AppSettings extends Equatable {
  const AppSettings({
    required this.onboardingCompleted,
    required this.backendMode,
    required this.nativeEndpointBaseUrl,
    required this.gatewayEndpointBaseUrl,
  });

  const AppSettings.initial()
    : onboardingCompleted = false,
      backendMode = BackendMode.native,
      nativeEndpointBaseUrl = AppConstants.nativeBaseUrl,
      gatewayEndpointBaseUrl = '';

  final bool onboardingCompleted;
  final BackendMode backendMode;
  final String nativeEndpointBaseUrl;
  final String gatewayEndpointBaseUrl;

  /// Base URL for the currently active backend.
  ///
  /// Native falls back to the official host when empty so the app remains
  /// usable without explicit configuration. Gateway returns an empty string so
  /// the router can surface a "please configure" error.
  String get effectiveBaseUrl {
    switch (backendMode) {
      case BackendMode.native:
        final value = nativeEndpointBaseUrl.trim();
        return value.isNotEmpty ? value : AppConstants.nativeBaseUrl;
      case BackendMode.gateway:
        return gatewayEndpointBaseUrl.trim();
    }
  }

  String endpointBaseUrlFor(BackendMode mode) => switch (mode) {
    BackendMode.native => nativeEndpointBaseUrl,
    BackendMode.gateway => gatewayEndpointBaseUrl,
  };

  Map<String, Object?> toJson() => {
    'onboarding_completed': onboardingCompleted,
    'backend_mode': backendMode.name,
    'native_endpoint_base_url': nativeEndpointBaseUrl.trim(),
    'gateway_endpoint_base_url': gatewayEndpointBaseUrl.trim(),
  };

  factory AppSettings.fromJson(Map<String, Object?> json) {
    final backendMode = BackendMode.values.firstWhere(
      (mode) => mode.name == json['backend_mode']?.toString(),
      orElse: () => BackendMode.native,
    );
    final nativeUrl = json['native_endpoint_base_url']?.toString().trim() ?? '';
    final gatewayUrl =
        json['gateway_endpoint_base_url']?.toString().trim() ??
        json['gateway_base_url']?.toString().trim() ??
        '';
    // Legacy single-value migration: older backups stored one URL under
    // endpoint_base_url / gateway_base_url. Assign it to whichever backend was
    // active when the backup was made, preferring an explicit per-backend value.
    final legacyShared = json['endpoint_base_url']?.toString().trim() ?? '';
    String resolvedNative = nativeUrl;
    String resolvedGateway = gatewayUrl;
    if (legacyShared.isNotEmpty) {
      if (backendMode == BackendMode.native && resolvedNative.isEmpty) {
        resolvedNative = legacyShared;
      } else if (backendMode == BackendMode.gateway &&
          resolvedGateway.isEmpty) {
        resolvedGateway = legacyShared;
      }
    }
    if (resolvedNative.isEmpty && backendMode == BackendMode.native) {
      resolvedNative = AppConstants.nativeBaseUrl;
    }
    return AppSettings(
      onboardingCompleted: json['onboarding_completed'] == true,
      backendMode: backendMode,
      nativeEndpointBaseUrl: resolvedNative,
      gatewayEndpointBaseUrl: resolvedGateway,
    );
  }

  EndpointProfile get activeEndpoint => EndpointProfile(
    mode: backendMode,
    baseUrl: effectiveBaseUrl,
    credentialId: switch (backendMode) {
      BackendMode.native => AppConstants.nativeImageApiKey,
      BackendMode.gateway => AppConstants.gatewayImageApiKey,
    },
  );

  AppSettings copyWith({
    bool? onboardingCompleted,
    BackendMode? backendMode,
    String? nativeEndpointBaseUrl,
    String? gatewayEndpointBaseUrl,
  }) {
    return AppSettings(
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      backendMode: backendMode ?? this.backendMode,
      nativeEndpointBaseUrl:
          nativeEndpointBaseUrl ?? this.nativeEndpointBaseUrl,
      gatewayEndpointBaseUrl:
          gatewayEndpointBaseUrl ?? this.gatewayEndpointBaseUrl,
    );
  }

  @override
  List<Object?> get props => [
    onboardingCompleted,
    backendMode,
    nativeEndpointBaseUrl,
    gatewayEndpointBaseUrl,
  ];
}
