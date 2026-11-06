import 'package:transaction_sync/transaction_sync.dart';
export 'package:transaction_sync/transaction_sync.dart'
    show WalletRevisionState, WalletRevision, WalletKey, WalletLifecycle;

/// Wallet-owned invalidations. A revision is not a successful network sync.
final class WalletFacade {
  final Stream<WalletRevisionState> _revisions;
  const WalletFacade(this._revisions);

  Stream<WalletRevisionState> watchRevisions({String? walletId}) =>
      _revisions.where(
        (revision) => walletId == null || revision.stamp.key.id == walletId,
      );
}
