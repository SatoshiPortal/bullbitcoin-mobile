import 'package:primitives/primitives.dart';

import '../data/owner_keychain.dart';
import '../domain/failures.dart';

/// Test-only setup and inspection of historical Exchange entries.
final class LegacyExchangeKeychainFixture {
  final _store = OwnerKeychain();

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
