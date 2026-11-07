import 'package:bb_mobile/features/wallet/domain/default_wallet_secret_policy.dart';
import 'package:bb_mobile/features/wallet/domain/network_wallet_setup_failure.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_secret_references_repository.dart';
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
  final SettingsRepository _settings;
  final WalletSecretReferencesRepository _references;
  final Secrets? _secrets;

  LoadNetworkWalletSetupUsecase(
    this._settings,
    this._references, [
    this._secrets,
  ]);

  @useResult
  Future<Result<NetworkWalletSetup, NetworkWalletSetupFailure>>
  execute() async {
    try {
      final settings = await _settings.fetch();
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
      final references = await _references.list();
      if (references case Err(:final failure)) {
        return Err(NetworkWalletSetupReadFailure(failure));
      }
      final reusable = <Fingerprint>[];
      if (references case Ok(:final value)) {
        for (final fingerprint in value) {
          switch (await secrets.fetch(fingerprint)) {
            case Ok(:final value):
              if (defaultWalletSecretRefusal(value.info) == null) {
                reusable.add(fingerprint);
              }
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
