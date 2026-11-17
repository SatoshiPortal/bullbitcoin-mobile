import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

import 'sqlite_ark_funding_reservations.dart';

/// The configured source authority must commit exposure BEFORE Secrets reads.
/// On Ark-capable networks, unavailable inventory never permits signing.
/// Explicit non-Ark Bitcoin networks keep their ordinary signer behavior.
final class ArkFundingSigningGuard {
  final Result<SqliteArkFundingReservations, SyncFailure> _authority;

  const ArkFundingSigningGuard(this._authority);

  Future<Result<void, SyncFailure>> admit({
    required WalletKey key,
    required String unsignedPsbt,
  }) {
    // The canonical native policy denies these networks, and the production
    // Board actor accepts only regtest accounts and regtest source wallets.
    // Neither a disabled profile nor missing metadata supplies this exemption.
    if (const {
          BitcoinNetwork.mainnet,
          BitcoinNetwork.testnet,
          BitcoinNetwork.signet,
        }.contains(key.network) &&
        !NetworkCapabilities.supports(key.network, NetworkCapability.ark)) {
      return Future.value(const Ok(null));
    }
    // New networks and future capability changes never gain a default bypass.
    return switch (_authority) {
      Ok(:final value) => value.admitOrdinarySigning(
        key: key,
        unsignedPsbt: unsignedPsbt,
      ),
      Err(:final failure) => Future.value(Err(failure)),
    };
  }
}
