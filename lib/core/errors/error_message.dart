import 'package:dio/dio.dart';

import '../network/network_error_mapper.dart';
import 'app_exception.dart';

/// Converts any thrown object into a message suitable for direct display.
///
/// Domain exceptions already carry a localized message, Dio failures go through
/// [NetworkErrorMapper], and everything else is stripped of Dart's runtime
/// prefixes such as `Bad state: ` or `StateError: `.
String friendlyErrorMessage(Object error) {
  if (error is AppException) return error.message;
  if (error is DioException) return NetworkErrorMapper.map(error).message;
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst(RegExp(r'^\w+(Exception|Error): '), '');
}
