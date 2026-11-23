import 'wallet_history_events.dart';

/// Invalidates this feature's read model without triggering network work.
final class WatchWalletRevisionsUsecase {
  final WalletHistoryEvents _wallet;
  const WatchWalletRevisionsUsecase(this._wallet);

  Stream<String> execute({String? walletId}) => _wallet
      .watchRevisions(walletId: walletId)
      .map((revision) => revision.stamp.key.id);
}
