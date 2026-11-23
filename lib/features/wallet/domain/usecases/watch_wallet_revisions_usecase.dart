import 'package:sync/sync.dart' show WalletRevisionState;

/// Invalidates this feature's read model without triggering network work.
final class WatchWalletRevisionsUsecase {
  final Stream<WalletRevisionState> _revisions;
  const WatchWalletRevisionsUsecase(this._revisions);

  Stream<String> execute({String? walletId}) => _revisions
      .map((revision) => revision.stamp.key.id)
      .where((id) => walletId == null || id == walletId);
}
