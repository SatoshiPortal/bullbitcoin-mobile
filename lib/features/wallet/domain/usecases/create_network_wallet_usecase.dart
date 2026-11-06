import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/domain/repositories/wallet_secret_references_repository.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

/// Provision from an existing handle or generate via the existing resumable
/// default-wallet flow. Never delete a secret on failure.
final class CreateNetworkWalletUsecase {
  final SettingsRepository _settings;
  final WalletSecretReferencesRepository _references;
  final Secrets _secrets;
  final CreateDefaultWalletsUsecase _createDefaults;

  CreateNetworkWalletUsecase(
    this._settings,
    this._references,
    this._secrets,
    this._createDefaults,
  );

  @useResult
  Future<Result<void, WalletFailure>> execute({
    required NetworkEnv network,
    Fingerprint? reuse,
  }) async {
    try {
      final settings = await _settings.fetch();
      if (network == NetworkEnv.mainnet ||
          network == NetworkEnv.signet ||
          settings.environment.networkEnv != network ||
          settings.isDevModeEnabled != true ||
          settings.isSuperuser != true) {
        log.warning('Network wallet setup refused category=context');
        return const Err(
          WalletUnexpectedFailure('Developer network unavailable'),
        );
      }
      Secret? secret;
      if (reuse != null) {
        switch (await _references.list()) {
          case Err(:final failure):
            return Err(failure);
          case Ok(:final value) when !value.contains(reuse):
            return const Err(WalletNotFoundFailure());
          case Ok():
            break;
        }
        switch (await _secrets.fetch(reuse)) {
          case Err():
            return const Err(WalletStorageFailure());
          case Ok(:final value):
            secret = value;
        }
        if (secret.info.hasPassphrase ||
            (network == NetworkEnv.testnet &&
                secret.info.kind != SecretKind.mnemonic)) {
          log.warning('Network wallet setup refused category=secretKind');
          return const Err(
            WalletUnexpectedFailure('Default secret unsupported'),
          );
        }
      }
      await _createDefaults.execute(secret: secret, expectedNetwork: network);
      log.fine(
        'Network wallet setup completed network=${network.name} reused=${reuse != null}',
      );
      return const Ok(null);
    } on Exception {
      log.warning('Network wallet setup unavailable category=provisioning');
      return const Err(WalletStorageFailure());
    }
  }
}
