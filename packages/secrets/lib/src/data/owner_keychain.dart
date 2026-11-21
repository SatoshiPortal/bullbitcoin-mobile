import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/boundary.dart';
import 'package:secrets/src/data/exceptions.dart';
import 'package:secrets/src/domain/domain.dart';

/// Closed legacy keyspace. No caller selects a key or prefix.
enum OwnerKey {
  // Explicit legacy-key allowance: AuthCubit originally stored the PIN here.
  pin('securityKey'),
  attempts('failedUnlockAttemptsKey'),
  lockedUntil('unlockLockedUntilKey'),
  exchange('exchange_api_key'),
  exchangeTestnet('exchange_api_key_testnet'),
  spBackend('sp_backend_config'),
  spAutoScan('sp_auto_scan_enabled');

  final String _key;
  const OwnerKey(this._key);
  bool get _reportsFailure =>
      this == pin || this == attempts || this == lockedUntil;
}

/// Internal transport; the plugin and arbitrary key access never leave data/.
final class OwnerKeychain {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
      migrateOnAlgorithmChange: false,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  @internal
  OwnerKeychain();

  Future<T> _unlocked<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on PlatformException catch (e) {
      if (e.details == -25308 ||
          e.code == '-25308' ||
          (e.message ?? '').contains('-25308')) {
        throw const KeystoreLockedException('device not unlocked since boot');
      }
      rethrow;
    }
  }

  Future<Result<String?, SecretFailure>> read(OwnerKey key) =>
      _read(key._key, reportFailure: key._reportsFailure);
  Future<Result<void, SecretFailure>> write(OwnerKey key, String value) =>
      _write(key._key, value, reportFailure: key._reportsFailure);
  Future<Result<void, SecretFailure>> delete(OwnerKey key) =>
      _delete(key._key, reportFailure: key._reportsFailure);

  Future<Result<String?, SecretFailure>> _read(
    String key, {
    bool reportFailure = false,
  }) => boundary(
    () => _unlocked(() => _storage.read(key: key)),
    orElse: FetchSecretFailure.new,
    reportFailure: reportFailure,
  );
  Future<Result<void, SecretFailure>> _write(
    String key,
    String value, {
    bool reportFailure = false,
  }) => boundary(
    () => _unlocked(() => _storage.write(key: key, value: value)),
    orElse: StoreSecretFailure.new,
    reportFailure: reportFailure,
  );
  Future<Result<void, SecretFailure>> _delete(
    String key, {
    bool reportFailure = false,
  }) => boundary(
    () => _unlocked(() => _storage.delete(key: key)),
    orElse: TrashSecretFailure.new,
    reportFailure: reportFailure,
  );

  // The engine already composes full legacy keys, including swap_regtest_.
  String _swapKey(String key) {
    if (!key.startsWith('swap_')) {
      throw ArgumentError('outside the swap secret scope');
    }
    return key;
  }

  Future<Result<String?, SecretFailure>> readSwap(String key) =>
      _read(_swapKey(key));
  Future<Result<void, SecretFailure>> writeSwap(String key, String value) =>
      _write(_swapKey(key), value);
  Future<Result<void, SecretFailure>> deleteSwap(String key) =>
      _delete(_swapKey(key));
}
