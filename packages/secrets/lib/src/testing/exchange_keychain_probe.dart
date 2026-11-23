import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

/// Native device-test seam over two isolated, fixed exchange probe entries.
/// Never exported by secrets.dart or usable by production consumers.
/// The production capability still composes its real keys and plugin options.
class ExchangeKeychainProbe extends FlutterSecureStoragePlatform {
  final FlutterSecureStoragePlatform _native;
  final _options = <String, Map<String, String>>{};
  bool refuseReads = false;

  ExchangeKeychainProbe() : _native = FlutterSecureStoragePlatform.instance;

  static const _prefix = '__credential_refactor_probe__';
  String _probeKey(String key) {
    if (key != 'exchange_api_key' && key != 'exchange_api_key_testnet') {
      throw ArgumentError('outside the exchange test scope');
    }
    return '$_prefix$key';
  }

  void install() => FlutterSecureStoragePlatform.instance = this;
  void restore() => FlutterSecureStoragePlatform.instance = _native;

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) {
    final scoped = _probeKey(key);
    if (refuseReads) throw PlatformException(code: 'synthetic-read-refusal');
    return _native.read(key: scoped, options: options);
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) {
    final scoped = _probeKey(key);
    _options[key] = Map.of(options);
    return _native.write(key: scoped, value: value, options: options);
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) => _native.delete(key: _probeKey(key), options: options);

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) => _native.containsKey(key: _probeKey(key), options: options);

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) =>
      throw UnsupportedError('exchange probes cannot list the keychain');
  @override
  Future<void> deleteAll({required Map<String, String> options}) =>
      throw UnsupportedError('exchange probes cannot clear the keychain');

  /// Cleanup is independent of the currently installed platform, including
  /// after a failed live probe. Only keys this wrapper wrote are addressed.
  Future<void> clearWrittenProbeKeys() async {
    for (final entry in _options.entries) {
      await _native.delete(key: _probeKey(entry.key), options: entry.value);
    }
    _options.clear();
  }
}
