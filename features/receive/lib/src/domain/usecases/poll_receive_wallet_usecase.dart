typedef PollReceiveWallet = Future<void> Function(
  String walletId, {
  required bool Function() isActive,
});

class PollReceiveWalletUsecase {
  final PollReceiveWallet _poll;

  const PollReceiveWalletUsecase(this._poll);

  Future<void> execute(String walletId, {required bool Function() isActive}) =>
      _poll(walletId, isActive: isActive);
}
