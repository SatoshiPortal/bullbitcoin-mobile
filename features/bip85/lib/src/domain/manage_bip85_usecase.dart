import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/bip85.dart';
import 'package:secrets/secrets.dart';

import 'bip85_failure.dart';

/// Resolve the default for the active environment for each command, without
/// opening a native wallet or requesting its descriptors.
final class ManageBip85Usecase {
  final Bip85Derivations _derivations;
  final WalletInventory _inventory;
  final ActiveEnvironmentReader _preferences;

  const ManageBip85Usecase(
    this._derivations,
    this._inventory,
    this._preferences,
  );

  Future<
    Result<List<({Bip85Derivation derivation, String entropy})>, Bip85Failure>
  >
  list() => _forDefault(_derivations.reveal);

  Future<Result<Bip85Derivation, Bip85Failure>> nextHex() => _forDefault(
    (parent) => _derivations.deriveNextHex(parent: parent, length: 30),
  );

  Future<Result<Bip85Derivation, Bip85Failure>> nextMnemonic() =>
      _forDefault((parent) => _derivations.deriveNextMnemonic(parent: parent));

  Future<Result<void, Bip85Failure>> rename(
    Bip85Derivation record,
    String alias,
  ) async => (await _derivations.rename(record, alias)).mapErr(_mapFailure);

  Future<Result<void, Bip85Failure>> setActive(
    Bip85Derivation record, {
    required bool active,
  }) async => (await _derivations.setActive(
    record,
    active: active,
  )).mapErr(_mapFailure);

  Future<Result<T, Bip85Failure>> _forDefault<T>(
    Future<Result<T, SecretFailure>> Function(Fingerprint) operation,
  ) async {
    final Environment environment;
    switch (await _preferences.readActiveEnvironment()) {
      case Err():
        return const Err(Bip85OperationFailure());
      case Ok(:final value):
        environment = value;
    }
    final network = switch (environment) {
      Environment.mainnet => BitcoinNetwork.mainnet,
      Environment.testnet => BitcoinNetwork.testnet,
      Environment.regtest => BitcoinNetwork.regtest,
    };
    switch (await _inventory.walletsForNetwork(network)) {
      case Err():
        return const Err(Bip85OperationFailure());
      case Ok(:final value):
        final wallet = value.defaults.firstOrNull;
        if (wallet == null) return const Err(Bip85NoDefaultWalletFailure());
        final fingerprint = wallet.masterFingerprint;
        if (fingerprint == null) {
          return const Err(Bip85OperationFailure());
        }
        return (await operation(fingerprint)).mapErr(_mapFailure);
    }
  }

  static Bip85Failure _mapFailure(SecretFailure _) =>
      const Bip85OperationFailure();
}
