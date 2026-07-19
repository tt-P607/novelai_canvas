import '../../../core/errors/app_exception.dart';

typedef JsonMap = Map<String, Object?>;

JsonMap asJsonMap(Object? value, {String context = '响应'}) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  throw DataParsingException('$context不是有效 JSON 对象。');
}

List<Object?> asJsonList(Object? value, {String context = '响应'}) {
  if (value is List) return value.cast<Object?>();
  throw DataParsingException('$context不是有效 JSON 数组。');
}

int? parseHeaderInt(Map<String, List<String>> headers, String name) {
  final values = headers.entries
      .where((entry) => entry.key.toLowerCase() == name.toLowerCase())
      .expand((entry) => entry.value)
      .toList();
  return values.isEmpty ? null : int.tryParse(values.first);
}
