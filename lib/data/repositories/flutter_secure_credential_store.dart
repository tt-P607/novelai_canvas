import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/repositories/secure_credential_store.dart';

class FlutterSecureCredentialStore implements SecureCredentialStore {
  FlutterSecureCredentialStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> clear() => _storage.deleteAll();
}
