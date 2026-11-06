import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_secret_references_repository.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';
import 'package:bull_logger/bull_logger.dart';

final class NetworkWalletSetup {
  final NetworkEnv network;
  final List<Fingerprint> reusable;

  const NetworkWalletSetup(this.network, this.reusable);
}

final class LoadNetworkWalletSetupUsecase {
  final SettingsRepository _settings;
  final WalletSecretReferencesRepository _references;

  LoadNetworkWalletSetupUsecase(this._settings, this._references);

  @useResult
  Future<Result<NetworkWalletSetup, WalletFailure>> execute() async {
    try {
      final settings = await _settings.fetch();
      final network = settings.environment.networkEnv;
      if (network == NetworkEnv.mainnet) {
        return const Ok(NetworkWalletSetup(NetworkEnv.mainnet, []));
      }
      if (settings.isDevModeEnabled != true || settings.isSuperuser != true) {
        log.warning('Network wallet setup refused category=developerMode');
        return const Err(WalletUnexpectedFailure('Developer network disabled'));
      }
      return (await _references.list()).map(
        (fingerprints) => NetworkWalletSetup(network, fingerprints),
      );
    } on Exception {
      log.warning('Network wallet setup unavailable category=settingsRead');
      return const Err(WalletStorageFailure());
    }
  }
}
