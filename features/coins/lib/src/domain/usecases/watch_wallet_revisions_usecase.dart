/// Invalidates this feature's read model without triggering network work.
final class WatchWalletRevisionsUsecase {
  final Stream<String> Function(String?) _watch;
  const WatchWalletRevisionsUsecase(this._watch);

  Stream<String> execute({String? walletId}) => _watch(walletId);
}
