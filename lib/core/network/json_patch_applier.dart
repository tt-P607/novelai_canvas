import '../errors/app_exception.dart';

typedef JsonMap = Map<String, Object?>;

abstract final class JsonPatchApplier {
  static JsonMap apply(JsonMap source, List<JsonMap> operations) {
    final result = _deepCopyMap(source);
    for (final operation in operations) {
      final op = operation['op']?.toString();
      final path = operation['path']?.toString();
      if (op == null || path == null) {
        throw const ConfigurationException('JSON Patch 缺少 op 或 path。');
      }
      final segments = _segments(path);
      switch (op) {
        case 'add':
        case 'replace':
          _write(result, segments, operation['value'], add: op == 'add');
        case 'remove':
          _remove(result, segments);
        default:
          throw ConfigurationException('暂不支持 JSON Patch 操作：$op');
      }
    }
    return result;
  }

  static List<String> _segments(String path) {
    if (!path.startsWith('/')) {
      throw ConfigurationException('JSON Patch path 必须以 / 开头：$path');
    }
    return path
        .substring(1)
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map((segment) => segment.replaceAll('~1', '/').replaceAll('~0', '~'))
        .toList();
  }

  static void _write(
    JsonMap root,
    List<String> segments,
    Object? value, {
    required bool add,
  }) {
    if (segments.isEmpty) {
      throw const ConfigurationException('不允许替换请求根对象。');
    }
    final parent = _parent(root, segments);
    final key = segments.last;
    if (parent is Map<String, Object?>) {
      if (!add && !parent.containsKey(key)) {
        throw ConfigurationException('JSON Patch replace 路径不存在：/$key');
      }
      parent[key] = _deepCopy(value);
      return;
    }
    if (parent is List<Object?>) {
      if (key == '-' && add) {
        parent.add(_deepCopy(value));
        return;
      }
      final index = int.tryParse(key);
      if (index == null ||
          index < 0 ||
          index > parent.length ||
          (!add && index == parent.length)) {
        throw ConfigurationException('JSON Patch 数组索引无效：$key');
      }
      if (add) {
        parent.insert(index, _deepCopy(value));
      } else {
        parent[index] = _deepCopy(value);
      }
      return;
    }
    throw const ConfigurationException('JSON Patch 父节点不是容器。');
  }

  static void _remove(JsonMap root, List<String> segments) {
    if (segments.isEmpty) {
      throw const ConfigurationException('不允许删除请求根对象。');
    }
    final parent = _parent(root, segments);
    final key = segments.last;
    if (parent is Map<String, Object?>) {
      if (!parent.containsKey(key)) {
        throw ConfigurationException('JSON Patch remove 路径不存在：/$key');
      }
      parent.remove(key);
      return;
    }
    if (parent is List<Object?>) {
      final index = int.tryParse(key);
      if (index == null || index < 0 || index >= parent.length) {
        throw ConfigurationException('JSON Patch 数组索引无效：$key');
      }
      parent.removeAt(index);
      return;
    }
    throw const ConfigurationException('JSON Patch 父节点不是容器。');
  }

  static Object _parent(JsonMap root, List<String> segments) {
    Object current = root;
    for (final segment in segments.take(segments.length - 1)) {
      if (current is Map<String, Object?>) {
        final next = current[segment];
        if (next == null) {
          throw ConfigurationException('JSON Patch 路径不存在：$segment');
        }
        current = next;
      } else if (current is List<Object?>) {
        final index = int.tryParse(segment);
        if (index == null || index < 0 || index >= current.length) {
          throw ConfigurationException('JSON Patch 数组索引无效：$segment');
        }
        current = current[index] as Object;
      } else {
        throw ConfigurationException('JSON Patch 路径不可遍历：$segment');
      }
    }
    return current;
  }

  static JsonMap _deepCopyMap(JsonMap source) =>
      source.map((key, value) => MapEntry(key, _deepCopy(value)));

  static Object? _deepCopy(Object? value) => switch (value) {
    Map<String, Object?> map => _deepCopyMap(map),
    List<Object?> list => list.map(_deepCopy).toList(),
    _ => value,
  };
}
