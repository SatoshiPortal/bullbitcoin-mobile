import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

/// Reads all visible wallet fingerprints on the active Bitcoin and Liquid networks.
class GetWalletsUsecase {
  final WalletInventory _inventory;
  final ActiveEnvironmentReader _preferences;

  const GetWalletsUsecase(this._inventory, this._preferences);

  @useResult
  Future<Result<Set<String>, SecretFailure>> execute() async {
    final environment = await _preferences.readActiveEnvironment();
    final networkEnv = switch (environment) {
      Ok(:final value) => value.networkEnv,
      Err() => null,
    };
    if (networkEnv == null) return const Err(FetchSecretFailure());
    final networks = <Network>[
      BitcoinNetwork.values.byName(networkEnv.name),
      LiquidNetwork.values.byName(networkEnv.name),
    ];
    final fingerprints = <String>{};
    for (final network in networks) {
      switch (await _inventory.walletsForNetwork(network)) {
        case Err():
          return const Err(FetchSecretFailure());
        case Ok(:final value):
          fingerprints.addAll(
            value.wallets
                .map((wallet) => wallet.masterFingerprint?.hex)
                .nonNulls,
          );
      }
    }
    return Ok(fingerprints);
  }
}
