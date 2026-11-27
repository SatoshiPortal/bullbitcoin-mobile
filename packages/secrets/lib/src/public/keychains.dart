import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/data.dart';
import 'package:secrets/src/domain/domain.dart';

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
