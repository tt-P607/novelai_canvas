sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

class ConfigurationException extends AppException {
  const ConfigurationException(super.message, {super.cause});
}

class NetworkException extends AppException {
  const NetworkException(
    super.message, {
    super.cause,
    this.statusCode,
    this.responseBody,
  });

  final int? statusCode;
  final Object? responseBody;
}

class AuthenticationException extends NetworkException {
  const AuthenticationException(
    super.message, {
    super.cause,
    super.statusCode,
    super.responseBody,
  });
}

class UnsupportedFeatureException extends AppException {
  const UnsupportedFeatureException(super.message, {super.cause});
}

class DataParsingException extends AppException {
  const DataParsingException(super.message, {super.cause});
}
