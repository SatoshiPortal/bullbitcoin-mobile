import 'package:bb_mobile/features/wallet/domain/default_wallet_secret_policy.dart';
import 'package:bb_mobile/features/wallet/domain/network_wallet_setup_failure.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:secrets/storage.dart' show WalletInventory;
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';
import 'package:secrets/secrets.dart';
import 'package:bull_logger/bull_logger.dart';

final class NetworkWalletSetup {
  final NetworkEnv network;
  final List<Fingerprint> reusable;

  const NetworkWalletSetup(this.network, this.reusable);
}

final class LoadNetworkWalletSetupUsecase {
  final DeveloperEnvironmentReader _settings;
  final WalletInventory _inventory;
  final Secrets? _secrets;

  LoadNetworkWalletSetupUsecase(
    this._settings,
    this._inventory, [
    this._secrets,
  ]);

  @useResult
  Future<Result<NetworkWalletSetup, NetworkWalletSetupFailure>>
  execute() async {
    try {
      final settings = (await _settings.readDeveloperEnvironment()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      );
      final network = settings.environment.networkEnv;
      if (network == NetworkEnv.mainnet) {
        return const Ok(NetworkWalletSetup(NetworkEnv.mainnet, []));
      }
      if (settings.isDevModeEnabled != true || settings.isSuperuser != true) {
        log.warning('Network wallet setup refused category=developerMode');
        return const Err(NetworkWalletSetupContextFailure());
      }
      final secrets = _secrets;
      // Without custody capability, setup can still generate or import, but
      // cannot offer an unchecked reference for reuse.
      if (secrets == null) return Ok(NetworkWalletSetup(network, const []));
      final references = await _inventory.referencedFingerprints();
      if (references case Err()) {
        return const Err(NetworkWalletSetupReadFailure(WalletStorageFailure()));
      }
      final reusable = <Fingerprint>[];
      if (references case Ok(:final value)) {
        for (final fingerprint in value) {
          switch (await secrets.fetch(fingerprint)) {
            case Ok(:final value):
              if (defaultWalletSecretRefusal(value.info) == null) {
                reusable.add(fingerprint);
              }
            case Err(failure: SecretNotFoundFailure()):
              // Public descriptors can reference secrets held outside the app.
              continue;
            case Err():
              return const Err(NetworkWalletSetupUnavailableFailure());
          }
        }
      }
      return Ok(NetworkWalletSetup(network, reusable));
    } on Exception {
      log.warning('Network wallet setup unavailable category=settingsRead');
      return const Err(NetworkWalletSetupUnavailableFailure());
    }
  }
}
