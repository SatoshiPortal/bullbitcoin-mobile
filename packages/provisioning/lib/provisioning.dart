import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import 'provisioning_failure.dart';
import 'src/wallet_provisioning.dart';

export 'default_wallets.dart';
export 'src/wallet_provisioning.dart'
    show WalletProvisioning, WalletProvisioningException, WatchOnlyAccount;
export 'network_wallet_provisioning.dart';
export 'provisioning_failure.dart';
export 'src/default_wallet_secret_policy.dart' show DefaultWalletSecretRefusal;

/// Adds the missing half of a legacy default pair using its existing seed.
final class DefaultWalletRepair {
  final Secrets _secrets;
  final WalletProvisioning _accounts;

  const DefaultWalletRepair(this._secrets, this._accounts);

  @useResult
  Future<Result<bool, ProvisioningFailure>> execute(
    List<WalletRegistration> defaults, {
    required BitcoinNetwork bitcoin,
    required LiquidNetwork liquid,
  }) async {
    if (defaults.isEmpty) return const Ok(false);
    final bitcoinDefaults = defaults
        .where((wallet) => wallet.network == bitcoin)
        .toList();
    final liquidDefaults = defaults
        .where((wallet) => wallet.network == liquid)
        .toList();
    if (bitcoinDefaults.length > 1 ||
        liquidDefaults.length > 1 ||
        bitcoinDefaults.length + liquidDefaults.length != defaults.length) {
      return const Err(DefaultWalletRepairFailure());
    }
    final Network missing;
    if (bitcoinDefaults.isEmpty) {
      missing = bitcoin;
    } else if (NetworkCapabilities.supports(
          liquid,
          NetworkCapability.softwareWallet,
        ) &&
        liquidDefaults.isEmpty) {
      missing = liquid;
    } else {
      return const Ok(false);
    }

    final fingerprint = defaults.first.secretFingerprint;
    if (fingerprint == null ||
        defaults.any(
          (wallet) =>
              wallet.signer != WalletSigner.local ||
              wallet.secretFingerprint != fingerprint,
        )) {
      return const Err(DefaultWalletRepairFailure());
    }
    switch (await _secrets.fetch(fingerprint)) {
      case Ok(:final value):
        switch (await _accounts.createDefault(value, missing)) {
          case Ok():
            return const Ok(true);
          case Err(:final failure):
            log.warning('Default wallet repair failed: ${failure.runtimeType}');
            return const Err(DefaultWalletRepairFailure());
        }
      case Err(:final failure):
        log.warning('Default wallet repair deferred: ${failure.runtimeType}');
        return const Err(DefaultWalletRepairFailure());
    }
  }
}
