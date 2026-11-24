import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:provisioning/provisioning.dart';
import 'package:secrets/secrets.dart';

import '../app_startup_failure.dart';

class CheckForExistingDefaultWalletsUsecase {
  final ActiveEnvironmentReader _preferences;
  final WalletInventory _inventory;
  final Future<Result<bool, SecretFailure>> Function() _hasWallets;
  final Secrets _secrets;
  final DefaultWalletRepair _repair;

  const CheckForExistingDefaultWalletsUsecase({
    required this._preferences,
    required this._inventory,
    required this._hasWallets,
    required this._secrets,
    required this._repair,
  });

  @useResult
  Future<Result<bool, AppStartupFailure>> execute() async {
    try {
      return await _check();
    } on Object catch (error, trace) {
      log.severe(
        message: 'Default wallet check failed at startup',
        error: error,
        trace: trace,
      );
      return const Err(AppStartupWalletCheckFailure());
    }
  }

  Future<Result<bool, AppStartupFailure>> _check() async {
    final environment = await _preferences.readActiveEnvironment();
    if (environment case Err(:final failure)) return Err(_readFailed(failure));
    final env = (environment as Ok<Environment, PreferencesFailure>).value;
    final bitcoin = BitcoinNetwork.values.byName(env.networkEnv.name);
    final liquid = LiquidNetwork.values.byName(env.networkEnv.name);
    final read = await _readDefaults(bitcoin, liquid);
    if (read case Err(:final failure)) return Err(failure);
    var defaults =
        (read as Ok<List<WalletRegistration>, AppStartupFailure>).value;

    if (defaults.isEmpty) {
      // Existing wallets on another environment still route to home.
      return (await _hasWallets()).mapErr(_readFailed);
    }

    if (await _repair.execute(defaults, bitcoin: bitcoin, liquid: liquid)
        case Ok(value: true)) {
      switch (await _readDefaults(bitcoin, liquid)) {
        case Ok(:final value):
          defaults = value;
        case Err(:final failure):
          log.warning(
            'Default wallets re-read after repair failed: ${failure.runtimeType}',
          );
      }
    }

    for (final wallet in defaults) {
      final fingerprint = wallet.secretFingerprint;
      if (wallet.signer != WalletSigner.local || fingerprint == null) {
        return const Err(AppStartupWalletCheckFailure());
      }
      switch (await _secrets.fetch(fingerprint)) {
        case Ok():
          break;
        case Err(failure: KeystoreLockedFailure()):
          return const Err(AppStartupKeychainLockedFailure());
        case Err(failure: SecretNotFoundFailure()):
          final matches = defaults
              .where(
                (candidate) =>
                    candidate.network == bitcoin &&
                    candidate.signer == WalletSigner.local &&
                    candidate.secretFingerprint == fingerprint,
              )
              .toList();
          if (matches.length != 1) {
            return const Err(
              AppStartupWalletCheckFailure(
                'matching Bitcoin default unavailable or ambiguous',
              ),
            );
          }
          return Err(
            AppStartupMissingDefaultSecretFailure(
              fingerprint.hex,
              walletId: matches.single.id,
            ),
          );
        case Err(:final failure):
          return Err(_readFailed(failure));
      }
    }
    return const Ok(true);
  }

  Future<Result<List<WalletRegistration>, AppStartupFailure>> _readDefaults(
    BitcoinNetwork bitcoin,
    LiquidNetwork liquid,
  ) async {
    final defaults = <WalletRegistration>[];
    for (final network in <Network>[bitcoin, liquid]) {
      switch (await _inventory.walletsForNetwork(network)) {
        case Ok(value: final selection) when selection.isComplete:
          defaults.addAll(selection.defaults);
        case Ok():
          return const Err(
            AppStartupWalletCheckFailure('incomplete wallet inventory'),
          );
        case Err(:final failure):
          return Err(_readFailed(failure));
      }
    }
    return Ok(defaults..sort((left, right) => left.id.compareTo(right.id)));
  }

  AppStartupFailure _readFailed(Failure failure) {
    log.warning(
      'Default wallet check failed at startup: ${failure.runtimeType}',
    );
    return AppStartupWalletCheckFailure(
      'default wallets read failed: ${failure.runtimeType}',
    );
  }
}
