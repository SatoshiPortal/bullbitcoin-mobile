import 'package:bull_recoverbull/bull_recoverbull.dart' show RecoverBullFailure;
import 'package:bull_recoverbull/storage.dart' show WalletBackupUsage;
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import 'network_failure.dart';

/// Selects diagnostics from the admitted inventory and RecoverBull history.
final class ReadWalletNetworkUsecase {
  final WalletInventory _inventory;
  final ActiveEnvironmentReader _preferences;
  final Future<Result<WalletBackupUsage?, RecoverBullFailure>> Function(String)
  _readBackup;

  const ReadWalletNetworkUsecase(
    this._inventory,
    this._preferences,
    this._readBackup,
  );

  Future<Result<NetworkEnv?, NetworkFailure>> defaultNetwork() async {
    final environment = await _preferences.readActiveEnvironment();
    if (environment case Ok(:final value)) {
      final active = value.networkEnv;
      for (final network in [
        ...BitcoinNetwork.values.where((network) => network.env == active),
        ...LiquidNetwork.values.where((network) => network.env == active),
      ]) {
        switch (await _inventory.walletsForNetwork(network)) {
          case Ok(value: final selection) when selection.defaults.isNotEmpty:
            return Ok(active);
          case Ok(value: final selection) when selection.isComplete:
            continue;
          case Ok() || Err():
            return const Err(NetworkUnexpectedFailure());
        }
      }
      return const Ok(null);
    }
    return const Err(NetworkUnexpectedFailure());
  }

  Future<Result<bool, NetworkFailure>> requiresTor() async {
    final selection = await _inventory.walletsForNetwork(
      BitcoinNetwork.mainnet,
    );
    if (selection case Ok(:final value) when value.isComplete) {
      final wallet = value.defaults.firstOrNull;
      if (wallet == null) return const Ok(false);
      return (await _readBackup(wallet.id))
          .map((backup) => backup?.latestEncryptedBackup != null)
          .mapErr((_) => const NetworkUnexpectedFailure());
    }
    return const Err(NetworkUnexpectedFailure());
  }
}
