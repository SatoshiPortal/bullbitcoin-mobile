import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

sealed class ProvisioningFailure extends Failure {
  const ProvisioningFailure();
}

final class DefaultWalletRepairFailure extends ProvisioningFailure {
  const DefaultWalletRepairFailure();
}

/// Adds the missing half of a legacy default pair using its existing seed.
final class DefaultWalletRepair {
  final Secrets _secrets;
  final Future<void> Function(Secret, Network) _create;

  const DefaultWalletRepair(this._secrets, this._create);

  Future<Result<bool, ProvisioningFailure>> execute(
    List<WalletRegistration> defaults, {
    required BitcoinNetwork bitcoin,
    required LiquidNetwork liquid,
  }) async {
    if (defaults.isEmpty) return const Ok(false);
    final Network missing;
    if (!defaults.any((wallet) => wallet.network == bitcoin)) {
      missing = bitcoin;
    } else if (NetworkCapabilities.supports(
          liquid,
          NetworkCapability.softwareWallet,
        ) &&
        !defaults.any((wallet) => wallet.network == liquid)) {
      missing = liquid;
    } else {
      return const Ok(false);
    }

    final fingerprint = defaults.first.masterFingerprint;
    if (fingerprint == null) return const Err(DefaultWalletRepairFailure());
    switch (await _secrets.fetch(fingerprint)) {
      case Ok(:final value):
        try {
          await _create(value, missing);
          return const Ok(true);
        } on Exception catch (error) {
          log.warning('Default wallet repair failed: ${error.runtimeType}');
          return const Err(DefaultWalletRepairFailure());
        }
      case Err(:final failure):
        log.warning('Default wallet repair deferred: ${failure.runtimeType}');
        return const Err(DefaultWalletRepairFailure());
    }
  }
}
