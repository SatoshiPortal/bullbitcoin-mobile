import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/data.dart';
import 'package:secrets/src/domain/domain.dart';

/// Access-owned legacy entries. PIN comparison stays inside custody.
final class AccessKeychain {
  final _store = OwnerKeychain();
  @internal
  AccessKeychain();

  Future<Result<bool, SecretFailure>> isPinSet() async =>
      (await _store.read(OwnerKey.pin)).map((pin) => pin != null);

  /// Null means absent; false means an existing PIN did not match.
  Future<Result<bool?, SecretFailure>> verifyPin(String candidate) async =>
      (await _store.read(OwnerKey.pin))
          .map((pin) => pin == null ? null : pin == candidate);
  Future<Result<void, SecretFailure>> setPin(String pin) =>
      _store.write(OwnerKey.pin, pin);
  Future<Result<void, SecretFailure>> deletePin() =>
      _store.delete(OwnerKey.pin);
  Future<Result<String?, SecretFailure>> readAttempts() =>
      _store.read(OwnerKey.attempts);
  Future<Result<void, SecretFailure>> writeAttempts(String value) =>
      _store.write(OwnerKey.attempts, value);
  Future<Result<String?, SecretFailure>> readLockedUntil() =>
      _store.read(OwnerKey.lockedUntil);
  Future<Result<void, SecretFailure>> writeLockedUntil(String value) =>
      _store.write(OwnerKey.lockedUntil, value);
  Future<Result<void, SecretFailure>> deleteLockedUntil() =>
      _store.delete(OwnerKey.lockedUntil);
}

/// Exchange-owned credentials; environment selects one of two fixed keys.
final class ExchangeKeychain {
  final _store = OwnerKeychain();
  @internal
  ExchangeKeychain();
  OwnerKey _key(bool isTestnet) =>
      isTestnet ? OwnerKey.exchangeTestnet : OwnerKey.exchange;
  Future<Result<String?, SecretFailure>> read({required bool isTestnet}) =>
      _store.read(_key(isTestnet));
  Future<Result<void, SecretFailure>> write(
    String value, {
    required bool isTestnet,
  }) => _store.write(_key(isTestnet), value);
  Future<Result<void, SecretFailure>> delete({required bool isTestnet}) =>
      _store.delete(_key(isTestnet));
}

/// Non-secret SP settings retained in their existing store for upgrade compatibility.
final class SilentPaymentKeychain {
  final _store = OwnerKeychain();
  @internal
  SilentPaymentKeychain();
  Future<Result<String?, SecretFailure>> readBackend() =>
      _store.read(OwnerKey.spBackend);
  Future<Result<void, SecretFailure>> writeBackend(String value) =>
      _store.write(OwnerKey.spBackend, value);
  Future<Result<void, SecretFailure>> deleteBackend() =>
      _store.delete(OwnerKey.spBackend);
  Future<Result<String?, SecretFailure>> readAutoScan() =>
      _store.read(OwnerKey.spAutoScan);
  Future<Result<void, SecretFailure>> writeAutoScan(String value) =>
      _store.write(OwnerKey.spAutoScan, value);
}

/// Engine credentials restricted to the fixed legacy swap_ namespace.
final class SwapKeychain {
  final _store = OwnerKeychain();
  @internal
  SwapKeychain();
  Future<Result<String?, SecretFailure>> read(String key) =>
      _store.readSwap(key);
  Future<Result<void, SecretFailure>> write(String key, String value) =>
      _store.writeSwap(key, value);
  Future<Result<void, SecretFailure>> delete(String key) =>
      _store.deleteSwap(key);
}
