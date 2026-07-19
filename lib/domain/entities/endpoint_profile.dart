import 'package:equatable/equatable.dart';

import '../../core/network/backend_mode.dart';

class EndpointProfile extends Equatable {
  const EndpointProfile({
    required this.mode,
    required this.baseUrl,
    this.credentialId,
  });

  final BackendMode mode;
  final String baseUrl;
  final String? credentialId;

  EndpointProfile copyWith({
    BackendMode? mode,
    String? baseUrl,
    String? credentialId,
    bool clearCredentialId = false,
  }) {
    return EndpointProfile(
      mode: mode ?? this.mode,
      baseUrl: baseUrl ?? this.baseUrl,
      credentialId: clearCredentialId
          ? null
          : credentialId ?? this.credentialId,
    );
  }

  @override
  List<Object?> get props => [mode, baseUrl, credentialId];
}
