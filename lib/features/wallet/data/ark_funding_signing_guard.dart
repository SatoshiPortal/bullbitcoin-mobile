import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

import 'sqlite_ark_funding_reservations.dart';
import 'ark_installation_state.dart';

/// The configured source authority must commit exposure BEFORE Secrets reads.
/// On Ark-capable networks, unavailable initialized inventory refuses signing.
/// Explicit non-Ark Bitcoin networks keep their ordinary signer behavior.
final class ArkFundingSigningGuard {
  final Result<SqliteArkFundingReservations, SyncFailure> _authority;

  final ArkInstallationState? _installation;

  const ArkFundingSigningGuard(this._authority, [this._installation]);

  Future<Result<void, SyncFailure>> admit({
    required WalletKey key,
    required String unsignedPsbt,
  }) async {
    // The canonical native policy denies these networks, and the production
    // Board actor accepts only regtest accounts and regtest source wallets.
    // Neither a disabled profile nor missing initialized metadata supplies this exemption.
    if (const {
          BitcoinNetwork.mainnet,
          BitcoinNetwork.testnet,
          BitcoinNetwork.signet,
        }.contains(key.network) &&
        !NetworkCapabilities.supports(key.network, NetworkCapability.ark)) {
      return const Ok(null);
    }
    // Ordinary-only regtest installations have no authority to open. Both
    // startup and the current inventory must positively prove no Ark state.
    if (key.network == BitcoinNetwork.regtest &&
        _authority is Err &&
        await _installation?.remainsUnprovisioned() == true) {
      return const Ok(null);
    }
    // New networks and future capability changes never gain a default bypass.
    return switch (_authority) {
      Ok(:final value) => value.admitOrdinarySigning(
        key: key,
        unsignedPsbt: unsignedPsbt,
      ),
      Err(:final failure) => Err(failure),
    };
  }
}
