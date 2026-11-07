export 'package:bb_mobile/features/wallet/domain/seed_reference_port.dart'
    show SeedReferences;
import 'package:transaction_sync/transaction_sync.dart';
import 'package:primitives/primitives.dart' show Result, Err;
import '../domain/wallet_discovery_failure.dart';
export 'package:primitives/primitives.dart' show Result;
export '../domain/wallet_discovery_failure.dart';

export 'package:transaction_sync/transaction_sync.dart'
    show WalletRevisionState, WalletRevision, WalletKey, WalletLifecycle;

/// Wallet-owned invalidations. A revision is not a successful network sync.
final class WalletFacade {
  final Stream<WalletRevisionState> _revisions;
  final Future<Result<void, WalletDiscoveryFailure>> Function(String)?
  _discoverWallet;
  const WalletFacade(this._revisions, {this._discoverWallet});

  Future<Result<void, WalletDiscoveryFailure>> discoverWallet(
    String walletId,
  ) async {
    final discover = _discoverWallet;
    if (discover == null) return const Err(WalletDiscoveryUnavailableFailure());
    return discover(walletId);
  }

  Stream<WalletRevisionState> watchRevisions({String? walletId}) =>
      _revisions.where(
        (revision) => walletId == null || revision.stamp.key.id == walletId,
      );
}
