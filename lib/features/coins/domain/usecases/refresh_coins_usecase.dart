/// Pull-to-refresh of one wallet's coins: a screen sync of that wallet through
/// the wallet owner, then the caller reloads its local coins.
class RefreshCoinsUsecase {
  final Future<void> Function(String) _pollWallet;

  RefreshCoinsUsecase(this._pollWallet);

  Future<void> execute({required String walletId}) async {
    try {
      await _pollWallet(walletId);
    } on Exception {
      // The wallet owner records sync failures itself. Let the caller reload
      // local coins so pull-to-refresh still settles cleanly.
    }
  }
}
