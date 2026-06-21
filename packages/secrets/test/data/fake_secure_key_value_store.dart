import 'package:secrets/src/data/datasources/keychain_locked_exception.dart';
import 'package:secrets/src/storage/secure_key_value_store.dart';

/// In-memory [SecureKeyValueStore] for unit tests. Can simulate a locked
/// keychain and a transient null read (eventual consistency).
class FakeSecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> _m = {};

  bool locked = false;

  /// Number of reads to return null for before serving the real value (models
  /// the eventual-consistency window the backoff loop exists for).
  int transientNullReads = 0;

  void seed(String key, String value) => _m[key] = value;

  void _checkLock() {
    if (locked) throw const KeychainLockedException();
  }

  @override
  Future<String?> read(String key) async {
    _checkLock();
    if (transientNullReads > 0) {
      transientNullReads--;
      return null;
    }
    return _m[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _checkLock();
    _m[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _checkLock();
    _m.remove(key);
  }

  @override
  Future<Map<String, String>> readAll() async {
    _checkLock();
    return Map.of(_m);
  }

  @override
  Future<bool> containsKey(String key) async {
    _checkLock();
    return _m.containsKey(key);
  }

  @override
  Future<void> deleteAll() async {
    _checkLock();
    _m.clear();
  }
}
