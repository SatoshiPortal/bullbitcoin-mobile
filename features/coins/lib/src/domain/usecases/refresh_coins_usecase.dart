/// Pull-to-refresh of one wallet's coins: a screen sync of that wallet through
/// the wallet owner, then the caller reloads its local coins.
class RefreshCoinsUsecase {
  final Future<void> Function(String) _poll;

  RefreshCoinsUsecase(this._poll);

  Future<void> execute({required String walletId}) async {
    try {
      await _poll(walletId);
    } on Exception {
      // The wallet owner records sync failures itself. Let the caller reload
      // local coins so pull-to-refresh still settles cleanly.
    }
  }
}
